require 'bigdecimal'

# Serviço responsável pela gestão de ajustes de comissão.
#
# Responsabilidades:
# - Detectar vendas canceladas após comissão finalizada/paga
# - Criar ajustes automáticos (sem duplicidade)
# - Criar ajustes manuais
#
# Regras:
# - Utiliza o commission_amount armazenado em commission_period_sales (não recalcula)
# - Índice único [cod_venda, commission_period_id, adjustment_type] impede duplicidade
# - Amount sempre positivo; direction determina se é débito ou crédito
# - Não modifica tabelas existentes (venda, funcionario, empresa)
#
class CommissionAdjustmentService
  class Error < StandardError; end
  class DuplicateAdjustmentError < Error; end

  # Detecta vendas canceladas em comissões finalizadas/pagas de um funcionário
  # e cria ajustes automáticos quando necessário.
  #
  # @param cod_funcionario [Integer] código do funcionário
  # @param cod_empresa [Integer] código da empresa
  # @return [Array<CommissionAdjustment>] ajustes criados
  def self.detect_cancelled_sales(cod_funcionario:, cod_empresa:)
    adjustments_created = []

    # Buscar todos os períodos finalizados/pagos deste funcionário
    closed_periods = CommissionPeriod
      .for_funcionario(cod_funcionario)
      .for_empresa(cod_empresa)
      .closed

    closed_periods.find_each do |period|
      # Para cada venda registrada neste período, verificar se foi cancelada
      period.commission_period_sales.find_each do |period_sale|
        # Verificar se a venda foi cancelada
        venda = Venda.find_by(cod_venda: period_sale.cod_venda)
        next unless venda&.cancelada?

        # Verificar se já existe ajuste para esta venda + período + tipo
        already_exists = CommissionAdjustment.exists?(
          cod_venda: period_sale.cod_venda,
          commission_period_id: period.id,
          adjustment_type: 'cancelled_sale'
        )
        next if already_exists

        # Criar ajuste usando o commission_amount já armazenado
        adjustment = CommissionAdjustment.create!(
          cod_funcionario: cod_funcionario,
          cod_empresa: cod_empresa,
          cod_venda: period_sale.cod_venda,
          commission_period_id: period.id,
          adjustment_type: 'cancelled_sale',
          direction: 'debit',
          reason: "Venda ##{period_sale.cod_venda} cancelada após comissão #{period.status} " \
                  "(período #{period.start_date.strftime('%d/%m/%Y')} a #{period.end_date.strftime('%d/%m/%Y')}). " \
                  "Valor original da venda: R$ #{period_sale.sale_value}",
          amount: period_sale.commission_amount,
          status: 'pending'
        )

        adjustments_created << adjustment
      end
    end

    adjustments_created
  end

  # Detecta vendas canceladas para TODOS os funcionários de uma empresa.
  #
  # @param cod_empresa [Integer] código da empresa
  # @return [Hash] { cod_funcionario => [adjustments] }
  def self.detect_cancelled_sales_for_empresa(cod_empresa:)
    results = {}

    # Buscar todos os funcionários com períodos finalizados/pagos
    func_ids = CommissionPeriod
      .for_empresa(cod_empresa)
      .closed
      .distinct
      .pluck(:cod_funcionario)

    func_ids.each do |func_id|
      adjustments = detect_cancelled_sales(
        cod_funcionario: func_id,
        cod_empresa: cod_empresa
      )
      results[func_id] = adjustments if adjustments.any?
    end

    results
  end

  # Cria um ajuste manual.
  #
  # @param params [Hash] parâmetros do ajuste
  # @option params [Integer] :cod_funcionario (obrigatório)
  # @option params [Integer] :cod_empresa (obrigatório)
  # @option params [BigDecimal] :amount (obrigatório, positivo)
  # @option params [String] :direction ('debit' ou 'credit')
  # @option params [String] :reason (obrigatório)
  # @option params [Integer] :created_by (obrigatório)
  # @option params [Integer] :cod_venda (opcional)
  # @option params [Integer] :commission_period_id (opcional, comissão de origem)
  # @return [CommissionAdjustment]
  def self.create_manual(params)
    CommissionAdjustment.create!(
      cod_funcionario: params[:cod_funcionario],
      cod_empresa: params[:cod_empresa],
      cod_venda: params[:cod_venda],
      commission_period_id: params[:commission_period_id],
      adjustment_type: 'manual',
      direction: params.fetch(:direction, 'debit'),
      reason: params[:reason],
      amount: params[:amount],
      status: 'pending',
      created_by: params[:created_by]
    )
  end

  # Cancela um ajuste pendente.
  #
  # @param adjustment [CommissionAdjustment]
  # @param cancelled_by [Integer] cod_funcionario que cancelou
  # @return [CommissionAdjustment]
  def self.cancel(adjustment, cancelled_by:)
    unless adjustment.pending?
      raise Error, "Apenas ajustes pendentes podem ser cancelados (status atual: #{adjustment.status})"
    end

    adjustment.update!(status: 'cancelled')
    adjustment
  end

  # Retorna o resumo de ajustes pendentes para um funcionário/empresa.
  #
  # @return [Hash] { total_debits:, total_credits:, net_adjustment:, count: }
  def self.pending_summary(cod_funcionario:, cod_empresa:)
    pending = CommissionAdjustment.pending
      .for_funcionario(cod_funcionario)
      .for_empresa(cod_empresa)

    total_debits = pending.debits.sum(:amount)
    total_credits = pending.credits.sum(:amount)

    {
      total_debits: total_debits,
      total_credits: total_credits,
      net_adjustment: total_debits - total_credits,
      count: pending.count
    }
  end
end
