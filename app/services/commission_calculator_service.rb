require 'bigdecimal'

# Serviço responsável pelo cálculo progressivo de comissões.
#
# Regras:
# - Utiliza exclusivamente BigDecimal para todos os cálculos financeiros.
# - A comissão é progressiva (não aplica a última faixa sobre o total).
# - As vendas são processadas em ordem: datavenda ASC, cod_venda ASC.
# - Cada venda recebe seu commission_amount individual.
# - A soma dos commission_amount individuais é igual ao total da comissão.
# - Arredondamento: HALF_UP para 2 casas decimais.
# - Ajuste de centavo aplicado na última venda para garantir soma exata.
#
class CommissionCalculatorService
  ROUNDING_MODE = :half_up
  SCALE = 2
  PERCENTAGE_DIVISOR = BigDecimal("100")

  # @param tiers [Array<CommissionTier>] faixas da regra, ordenadas por position
  # @param sales [Array] vendas ordenadas por datavenda ASC, cod_venda ASC
  #   Cada elemento deve responder a: cod_venda, valortotal, datavenda
  # @return [Hash] resultado com :total_commission, :sales_breakdown, :tiers_breakdown
  def initialize(tiers:, sales:)
    @tiers = tiers.sort_by(&:position)
    @sales = sales
  end

  def call
    return empty_result if @sales.empty? || @tiers.empty?

    accumulated = BigDecimal("0")
    sales_breakdown = []
    tiers_breakdown = build_tiers_accumulator

    @sales.each do |sale|
      sale_value = to_decimal(sale.valortotal)
      sale_start = accumulated
      sale_end = accumulated + sale_value
      sale_commission = BigDecimal("0")

      @tiers.each_with_index do |tier, idx|
        tier_floor = to_decimal(tier.min_value)
        tier_ceiling = tier.max_value.present? ? to_decimal(tier.max_value) : nil
        tier_percentage = to_decimal(tier.percentage)

        # Determinar a sobreposição entre a venda e esta faixa
        overlap_start = [sale_start, tier_floor].max

        if tier_ceiling
          overlap_end = [sale_end, tier_ceiling].min
        else
          overlap_end = sale_end
        end

        next if overlap_start >= overlap_end

        taxable = overlap_end - overlap_start
        tier_commission = taxable * (tier_percentage / PERCENTAGE_DIVISOR)
        sale_commission += tier_commission

        # Acumular no breakdown da faixa
        tiers_breakdown[idx][:taxable_amount] += taxable
        tiers_breakdown[idx][:commission] += tier_commission
      end

      # Arredondar comissão individual (ajuste de centavo na última venda depois)
      rounded_commission = sale_commission.round(SCALE, ROUNDING_MODE)

      sales_breakdown << {
        cod_venda: sale.cod_venda,
        sale_value: sale_value,
        sale_date: sale.datavenda,
        commission_amount: rounded_commission
      }

      accumulated = sale_end
    end

    # Calcular total bruto preciso (sem arredondamento intermediário)
    total_precise = calculate_total_precise(accumulated)

    # Somar as comissões individuais arredondadas
    sum_rounded = sales_breakdown.sum { |s| s[:commission_amount] }

    # Ajuste de centavo na última venda para garantir soma exata
    difference = total_precise - sum_rounded
    if difference != BigDecimal("0") && sales_breakdown.any?
      sales_breakdown.last[:commission_amount] += difference
    end

    # Recalcular soma após ajuste
    total_commission = sales_breakdown.sum { |s| s[:commission_amount] }

    # Arredondar tiers_breakdown
    tiers_breakdown.each do |tier_info|
      tier_info[:taxable_amount] = tier_info[:taxable_amount].round(SCALE, ROUNDING_MODE)
      tier_info[:commission] = tier_info[:commission].round(SCALE, ROUNDING_MODE)
    end

    {
      total_sales: accumulated.round(SCALE, ROUNDING_MODE),
      total_commission: total_commission,
      sales_breakdown: sales_breakdown,
      tiers_breakdown: tiers_breakdown
    }
  end

  private

  # Calcula o total de comissão sobre o valor acumulado (sem dividir por vendas)
  # para ter o valor de referência preciso
  def calculate_total_precise(total_sales)
    commission = BigDecimal("0")

    @tiers.each do |tier|
      tier_floor = to_decimal(tier.min_value)
      tier_ceiling = tier.max_value.present? ? to_decimal(tier.max_value) : nil
      tier_percentage = to_decimal(tier.percentage)

      if tier_ceiling
        taxable = [total_sales, tier_ceiling].min - tier_floor
      else
        taxable = total_sales - tier_floor
      end

      next if taxable <= BigDecimal("0")

      commission += taxable * (tier_percentage / PERCENTAGE_DIVISOR)
    end

    commission.round(SCALE, ROUNDING_MODE)
  end

  def build_tiers_accumulator
    @tiers.map do |tier|
      {
        position: tier.position,
        min_value: to_decimal(tier.min_value),
        max_value: tier.max_value.present? ? to_decimal(tier.max_value) : nil,
        percentage: to_decimal(tier.percentage),
        taxable_amount: BigDecimal("0"),
        commission: BigDecimal("0")
      }
    end
  end

  def to_decimal(value)
    case value
    when BigDecimal
      value
    when nil
      BigDecimal("0")
    else
      BigDecimal(value.to_s)
    end
  end

  def empty_result
    {
      total_sales: BigDecimal("0"),
      total_commission: BigDecimal("0"),
      sales_breakdown: [],
      tiers_breakdown: []
    }
  end
end
