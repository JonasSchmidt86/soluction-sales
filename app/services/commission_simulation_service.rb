require 'bigdecimal'

# Serviço de simulação de comissões em tempo real.
# Calcula on-the-fly sem gravar nada no banco.
# Usado para mostrar estimativas na tela de apurações.
#
class CommissionSimulationService
  # Simula a comissão de todos os vendedores com regra atribuída em uma empresa.
  #
  # @param cod_empresa [Integer]
  # @param start_date [Date] início do período (default: início do mês)
  # @param end_date [Date] fim do período (default: hoje)
  # @return [Array<Hash>] lista de simulações por vendedor
  def self.simulate_all(cod_empresa:, start_date: nil, end_date: nil)
    start_date ||= Date.today.beginning_of_month
    end_date ||= Date.today

    # Buscar todos os funcionários com assignment vigente nesta empresa
    assignments = CommissionAssignment
      .where(cod_empresa: cod_empresa)
      .where("start_date <= ?", end_date)
      .where("end_date IS NULL OR end_date >= ?", start_date)
      .includes(:commission_rule => :commission_tiers)

    # Agrupar por funcionário (pegar a mais recente se houver mais de uma)
    by_func = {}
    assignments.order(:start_date).each do |a|
      by_func[a.cod_funcionario] = a
    end

    results = []

    by_func.each do |cod_funcionario, assignment|
      result = simulate_one(
        cod_funcionario: cod_funcionario,
        cod_empresa: cod_empresa,
        start_date: start_date,
        end_date: end_date,
        assignment: assignment
      )
      results << result if result
    end

    results.sort_by { |r| -r[:total_sales].to_f }
  end

  # Simula a comissão de um vendedor específico.
  #
  # @return [Hash] ou nil se não tem regra
  def self.simulate_one(cod_funcionario:, cod_empresa:, start_date: nil, end_date: nil, assignment: nil)
    start_date ||= Date.today.beginning_of_month
    end_date ||= Date.today

    # Buscar assignment se não foi passado
    assignment ||= CommissionAssignment
      .where(cod_funcionario: cod_funcionario, cod_empresa: cod_empresa)
      .where("start_date <= ?", end_date)
      .where("end_date IS NULL OR end_date >= ?", start_date)
      .order(start_date: :desc)
      .includes(:commission_rule => :commission_tiers)
      .first

    return nil unless assignment

    rule = assignment.commission_rule
    tiers = rule.commission_tiers.ordered

    # Buscar vendas válidas do período
    sales = Venda.where(cod_funcionario: cod_funcionario, cod_empresa: cod_empresa)
                 .where(cancelada: [false, nil])
                 .where.not(tipo: 'T')
                 .where("datavenda >= ? AND datavenda <= ?", start_date.beginning_of_day, end_date.end_of_day)
                 .order(:datavenda, :cod_venda)

    # Calcular
    calc_result = CommissionCalculatorService.new(tiers: tiers, sales: sales).call

    # Buscar ajustes pendentes
    pending_debits = CommissionAdjustment.pending.debits
      .where(cod_funcionario: cod_funcionario, cod_empresa: cod_empresa).sum(:amount)
    pending_credits = CommissionAdjustment.pending.credits
      .where(cod_funcionario: cod_funcionario, cod_empresa: cod_empresa).sum(:amount)
    adjustments_total = pending_debits - pending_credits

    net = calc_result[:total_commission] - adjustments_total

    # Buscar nome do funcionário
    func = Funcionario.find_by(cod_funcionario: cod_funcionario)

    {
      cod_funcionario: cod_funcionario,
      funcionario_nome: func&.pessoa_nome || func&.usuario,
      rule_name: rule.name,
      start_date: start_date,
      end_date: end_date,
      sales_count: sales.count,
      total_sales: calc_result[:total_sales],
      commission_amount: calc_result[:total_commission],
      adjustments_amount: adjustments_total,
      net_commission: net
    }
  end
end
