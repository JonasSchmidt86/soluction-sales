require 'bigdecimal'

# Serviço responsável pela apuração de comissões.
#
# Responsabilidades:
# - Calcular/recalcular comissão de um período aberto
# - Finalizar período (congela valores, grava snapshots)
# - Marcar como paga
# - Reabrir período (com permissão administrativa)
#
# Regras:
# - Bloqueia finalização se existir mais de uma regra vigente no período
# - Utiliza CommissionCalculatorService para o cálculo progressivo
# - Aplica ajustes pendentes ao finalizar
# - Não modifica tabelas existentes (venda, funcionario, empresa)
#
class CommissionPeriodService
  class Error < StandardError; end
  class MultipleRulesError < Error; end
  class NoRuleError < Error; end
  class InvalidStatusError < Error; end
  class PermissionError < Error; end

  # @param period [CommissionPeriod] período de apuração
  def initialize(period)
    @period = period
  end

  # Calcula ou recalcula a comissão (apenas para períodos abertos)
  # @return [Hash] resultado do cálculo
  def calculate
    ensure_open!
    validate_single_rule!

    assignment = find_assignment!
    rule = assignment.commission_rule
    tiers = rule.commission_tiers.ordered

    # Buscar vendas válidas do período
    sales = @period.fetch_sales

    # Calcular comissão progressiva
    result = CommissionCalculatorService.new(tiers: tiers, sales: sales).call

    # Limpar vendas anteriores e gravar as novas
    ActiveRecord::Base.transaction do
      @period.commission_period_sales.destroy_all

      result[:sales_breakdown].each do |sale_data|
        @period.commission_period_sales.create!(
          cod_venda: sale_data[:cod_venda],
          sale_value: sale_data[:sale_value],
          sale_date: sale_data[:sale_date],
          commission_amount: sale_data[:commission_amount]
        )
      end

      # Buscar ajustes pendentes para este funcionário/empresa
      pending_adjustments = CommissionAdjustment.pending
        .for_funcionario(@period.cod_funcionario)
        .for_empresa(@period.cod_empresa)

      adjustments_total = pending_adjustments.debits.sum(:amount) -
                          pending_adjustments.credits.sum(:amount)

      # Atualizar período (sem finalizar)
      @period.update!(
        commission_rule: rule,
        total_sales: result[:total_sales],
        commission_amount: result[:total_commission],
        adjustments_amount: adjustments_total,
        net_commission: result[:total_commission] - adjustments_total
      )
    end

    {
      total_sales: @period.total_sales,
      commission_amount: @period.commission_amount,
      adjustments_amount: @period.adjustments_amount,
      net_commission: @period.net_commission,
      sales_count: @period.commission_period_sales.count,
      rule_name: rule.name,
      tiers_breakdown: result[:tiers_breakdown]
    }
  end

  # Finaliza o período (congela valores e grava snapshots)
  # @param finalized_by [Integer] cod_funcionario de quem finalizou
  def finalize(finalized_by:)
    ensure_open!
    validate_single_rule!

    # Garantir que foi calculado
    raise Error, "Período precisa ser calculado antes de finalizar" if @period.commission_amount.nil?

    assignment = find_assignment!
    rule = assignment.commission_rule
    tiers = rule.commission_tiers.ordered

    ActiveRecord::Base.transaction do
      # Gravar snapshot da regra e faixas
      rule_snapshot = {
        rule_id: rule.id,
        rule_name: rule.name,
        tiers: tiers.map { |t|
          {
            position: t.position,
            min_value: t.min_value.to_s,
            max_value: t.max_value&.to_s,
            percentage: t.percentage.to_s
          }
        }
      }

      # Gravar breakdown das faixas
      tiers_breakdown = calculate_tiers_breakdown(tiers)

      # Aplicar ajustes pendentes
      pending_adjustments = CommissionAdjustment.pending
        .for_funcionario(@period.cod_funcionario)
        .for_empresa(@period.cod_empresa)

      pending_adjustments.find_each do |adj|
        adj.update!(
          status: 'applied',
          applied_in_period_id: @period.id,
          applied_at: Time.current
        )
      end

      # Recalcular adjustments_amount com os ajustes agora aplicados
      applied_debits = @period.applied_adjustments.debits.sum(:amount)
      applied_credits = @period.applied_adjustments.credits.sum(:amount)
      adjustments_total = applied_debits - applied_credits

      @period.update!(
        status: 'finalized',
        rule_snapshot: rule_snapshot,
        tiers_breakdown: tiers_breakdown,
        adjustments_amount: adjustments_total,
        net_commission: @period.commission_amount - adjustments_total,
        finalized_at: Time.current,
        finalized_by: finalized_by
      )
    end

    @period
  end

  # Marca como paga
  # @param paid_by [Integer] cod_funcionario que marcou como paga
  def mark_as_paid(paid_by:)
    unless @period.finalized?
      raise InvalidStatusError, "Apenas comissões finalizadas podem ser marcadas como pagas"
    end

    ActiveRecord::Base.transaction do
      now = Time.current

      # Criar registro de pagamento (apenas se há valor positivo)
      if @period.net_commission && @period.net_commission > 0
        @period.commission_payments.create!(
          amount: @period.net_commission,
          paid_at: now,
          paid_by: paid_by
        )
      end

      @period.update!(
        status: 'paid',
        paid_at: now,
        paid_by: paid_by
      )
    end

    @period
  end

  # Reabre um período finalizado/pago (requer permissão administrativa)
  # @param reopened_by [Integer] cod_funcionario que reabriu
  # @param reason [String] motivo da reabertura
  def reopen(reopened_by:, reason:)
    unless @period.finalized? || @period.paid?
      raise InvalidStatusError, "Apenas comissões finalizadas ou pagas podem ser reabertas"
    end

    raise Error, "Motivo da reabertura é obrigatório" if reason.blank?

    ActiveRecord::Base.transaction do
      # Reverter ajustes que foram aplicados neste período
      @period.applied_adjustments.each do |adj|
        adj.update!(
          status: 'pending',
          applied_in_period_id: nil,
          applied_at: nil
        )
      end

      @period.update!(
        status: 'open',
        reopened_at: Time.current,
        reopened_by: reopened_by,
        reopen_reason: reason,
        finalized_at: nil,
        finalized_by: nil,
        paid_at: nil,
        paid_by: nil
      )
    end

    @period
  end

  private

  def ensure_open!
    unless @period.open?
      raise InvalidStatusError, "Esta operação só pode ser realizada em períodos abertos (status atual: #{@period.status})"
    end
  end

  def validate_single_rule!
    assignments = CommissionAssignment.rules_in_period(
      @period.cod_funcionario,
      @period.cod_empresa,
      @period.start_date,
      @period.end_date
    )

    if assignments.count > 1
      raise MultipleRulesError,
        "O período selecionado contém mais de uma regra de comissão vigente. " \
        "Divida a apuração em períodos correspondentes às regras."
    end

    if assignments.count == 0
      raise NoRuleError,
        "Nenhuma regra de comissão atribuída para este funcionário no período selecionado."
    end
  end

  def find_assignment!
    assignments = CommissionAssignment.rules_in_period(
      @period.cod_funcionario,
      @period.cod_empresa,
      @period.start_date,
      @period.end_date
    )
    assignments.first
  end

  def calculate_tiers_breakdown(tiers)
    sales = @period.commission_period_sales.ordered
    accumulated = BigDecimal("0")
    breakdown = tiers.map { |t|
      { position: t.position, min_value: t.min_value.to_s, max_value: t.max_value&.to_s,
        percentage: t.percentage.to_s, taxable_amount: "0", commission: "0" }
    }

    sales.each do |sale|
      sale_start = accumulated
      sale_end = accumulated + BigDecimal(sale.sale_value.to_s)

      tiers.each_with_index do |tier, idx|
        tier_floor = BigDecimal(tier.min_value.to_s)
        tier_ceiling = tier.max_value ? BigDecimal(tier.max_value.to_s) : nil

        overlap_start = [sale_start, tier_floor].max
        overlap_end = tier_ceiling ? [sale_end, tier_ceiling].min : sale_end

        next if overlap_start >= overlap_end

        taxable = overlap_end - overlap_start
        commission = taxable * (BigDecimal(tier.percentage.to_s) / BigDecimal("100"))

        breakdown[idx][:taxable_amount] = (BigDecimal(breakdown[idx][:taxable_amount]) + taxable).round(2).to_s
        breakdown[idx][:commission] = (BigDecimal(breakdown[idx][:commission]) + commission).round(2).to_s
      end

      accumulated = sale_end
    end

    breakdown
  end
end
