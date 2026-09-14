# Calcula, sob demanda, os dados de cada widget do dashboard.
#
# Só executa as queries dos widgets que estão ativos para o colaborador,
# evitando cálculos desnecessários. Cada dado é memoizado.
#
# Uso:
#   svc = DashboardDataService.new(current_collaborator)
#   svc.fetch('vendas_dia')  => Hash com os dados do widget
class DashboardDataService
  def initialize(collaborator)
    @cod_empresa = collaborator.cod_empresa
    @cod_funcionario = collaborator.cod_funcionario
    @cache = {}
  end

  # Retorna os dados de um widget (memoizado por tipo).
  def fetch(widget_type)
    @cache[widget_type] ||= compute(widget_type)
  end

  private

  def compute(widget_type)
    case widget_type
    when 'vendas_dia'     then vendas_dia
    when 'minhas_vendas'  then minhas_vendas
    when 'vendas_empresa' then vendas_empresa
    when 'caixa'          then caixa
    when 'financeiro'     then financeiro
    when 'estoque_minimo' then estoque_minimo
    when 'top_produtos'   then top_produtos
    when 'atendimentos'   then atendimentos
    when 'vendas_custo'   then vendas_custo
    when 'comissoes'      then comissoes
    when 'aniversariantes' then aniversariantes
    else {}
    end
  end

  def vendas_dia
    escopo = Venda.where(
      "DATE(datavenda) = ? AND cod_empresa = ? AND cod_funcionario = ? AND cancelada = false",
      Date.current, @cod_empresa, @cod_funcionario
    )
    total_v = Venda.where(
      "DATE(datavenda) = ? AND cod_empresa = ? AND cod_funcionario = ? AND tipo = 'V' AND cancelada = false",
      Date.current, @cod_empresa, @cod_funcionario
    )
    total = Venda.where(
      "DATE_PART('month', datavenda) = ? AND DATE_PART('year', datavenda) = ?
       AND cod_empresa = ? AND tipo = 'V' AND cancelada = false AND cod_funcionario = ?",
      Date.current.month, Date.current.year, @cod_empresa, @cod_funcionario
    ).sum(:valortotal) || 0
    {
      quantidade: total_v.count,
      total: total_v.sum(:valortotal) || 0,
      total_geral: escopo.sum(:valortotal) || 0,
      total_vendas: total, cod_funcionario: @cod_funcionario
    }
  end

  def minhas_vendas
    total = Venda.where(
      "DATE_PART('month', datavenda) = ? AND DATE_PART('year', datavenda) = ?
       AND cod_empresa = ? AND tipo = 'V' AND cancelada = false AND cod_funcionario = ?",
      Date.current.month, Date.current.year, @cod_empresa, @cod_funcionario
    ).sum(:valortotal) || 0
    { total: total, cod_funcionario: @cod_funcionario }
  end

  def vendas_empresa
    total = Venda.where(
      "DATE_PART('month', datavenda) = ? AND DATE_PART('year', datavenda) = ?
       AND cod_empresa = ? AND tipo = 'V' AND cancelada = false",
      Date.current.month, Date.current.year, @cod_empresa
    ).sum(:valortotal) || 0
    { total: total }
  end

  def caixa
    atual = Caixa.where(datafechamento: nil, cod_empresa: @cod_empresa).first
    entradas = atual&.valorentradas || 0
    saidas = atual&.valorsaidas || 0
    abertura = atual&.valorabertura || 0
    ultimo = Caixa.where(cod_empresa: @cod_empresa)
                  .where.not(datafechamento: nil)
                  .order(datafechamento: :desc)
                  .first
    {
      abertura: abertura,
      entradas: entradas,
      saidas: saidas,
      saldo: abertura + entradas - saidas,
      ultimo_fechamento: ultimo
    }
  end

  def financeiro
    total_pagar = Contaspagrec.where(
      "DATE_PART('month', dtvencimento) = ? AND DATE_PART('year', dtvencimento) = ?
       AND cod_empresa = ? AND cod_venda is null AND quitada = false",
      Date.current.month, Date.current.year, @cod_empresa
    ).sum(:valorparcela) || 0

    total_receber = Contaspagrec.where(
      "DATE_PART('month', dtvencimento) = ? AND DATE_PART('year', dtvencimento) = ?
       AND cod_empresa = ? AND cod_venda is not null AND ativo = true AND quitada = false",
      Date.current.month, Date.current.year, @cod_empresa
    ).sum(:valorparcela) || 0

    minhas = minhas_vendas[:total]
    empresa = vendas_empresa[:total]

    {
      minhas_vendas: minhas,
      total_vendas: empresa,
      total_pagar: total_pagar,
      total_receber: total_receber,
      cod_funcionario: @cod_funcionario
    }
  end

  def top_produtos
    produtos = Itemvenda.joins(:venda, :produto)
      .where(
        "DATE_PART('month', venda.datavenda) = ? AND DATE_PART('year', venda.datavenda) = ?
         AND venda.cod_empresa = ? AND venda.tipo = 'V' AND cancelada = false",
        Date.current.month, Date.current.year, @cod_empresa
      )
      .group("produto.nome, produto.cod_produto")
      .order("SUM(itemvenda.quantidade) DESC")
      .select("produto.nome, produto.cod_produto, SUM(itemvenda.quantidade) as total_vendido")
      .limit(50)
    { produtos: produtos }
  end

  def estoque_minimo
    itens = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        <<~SQL,
          SELECT
            CONCAT(p.cod_produto, '-', ep.cod_cor) AS codigo,
            p.nome,
            c.nmcor,
            ep.quantidademinima AS estoque_minimo,
            ep.quantidade AS estoque,
            COALESCE(SUM(ipc.quantidade), 0) AS quantidade_pedida,
            COALESCE(MAX(v3.total_vendido), 0) AS vendido_3_meses
          FROM empresaproduto ep
          JOIN produto p ON ep.cod_produto = p.cod_produto
          JOIN cores c ON c.cod_cor = ep.cod_cor
          LEFT JOIN itens_pedido_compras ipc
            ON ipc.cod_produto = ep.cod_produto
            AND ipc.cod_cor = ep.cod_cor
          LEFT JOIN pedidos_compras pc
            ON pc.id = ipc.pedidos_compra_id
            AND pc.cod_empresa = ep.cod_empresa
          LEFT JOIN LATERAL (
            SELECT SUM(iv.quantidade) AS total_vendido
            FROM itemvenda iv
            JOIN venda v ON v.cod_venda = iv.cod_venda and v.cancelada = false and v.tipo <> 'T'
            WHERE
              iv.cod_empresa = ep.cod_empresa
              AND iv.cod_produto = ep.cod_produto
              AND iv.cod_cor = ep.cod_cor
              AND v.datavenda >= CURRENT_DATE - INTERVAL '3 months'
          ) v3 ON true
          WHERE ep.cod_empresa = ?
            AND ep.quantidademinima > 0
            AND ep.ativo = true
          GROUP BY
            p.cod_produto, ep.cod_cor, p.nome, c.nmcor,
            ep.quantidademinima, ep.quantidade
          HAVING ep.quantidademinima >= (
            ep.quantidade + COALESCE(SUM(ipc.quantidade), 0)
          )
          ORDER BY vendido_3_meses DESC
          LIMIT 50;
        SQL
        @cod_empresa
      ])
    )
    { itens: itens }
  end

  def atendimentos
    hoje = Atendimento.where(company_id: @cod_empresa)
                      .where("DATE(attended_at) = ?", Date.current).count

    pendentes_scope = Atendimento.where(company_id: @cod_empresa)
                                 .where.not(return_at: nil)
                                 .where.not(status: :closed)
    retorno = pendentes_scope.count

    # Lista dos retornos pendentes mais próximos (para exibir no widget)
    pendentes = pendentes_scope.includes(:pessoa)
                               .order(:return_at)
                               .limit(50)

    { hoje: hoje, retorno: retorno, pendentes: pendentes }
  end

  # Receita x custo dos últimos 6 meses (mesma lógica do relatório DRE).
  def vendas_custo
    inicio = 5.months.ago.beginning_of_month.to_date
    fim = Date.current.end_of_month

    linhas = Venda
      .joins(:itensvenda)
      .where(cod_empresa: @cod_empresa)
      .where("tipo <> 'T'")
      .where(cancelada: false)
      .where("venda.datavenda BETWEEN ? AND ?", inicio, fim)
      .group(Arel.sql("DATE_TRUNC('month', venda.datavenda)"))
      .order(Arel.sql("DATE_TRUNC('month', venda.datavenda)"))
      .pluck(
        Arel.sql("DATE_TRUNC('month', venda.datavenda) AS mes"),
        Arel.sql("SUM(itemvenda.valorunitario * itemvenda.quantidade + ((itemvenda.valor_acrescimo - itemvenda.valor_desconto) / itemvenda.quantidade)) AS receita_bruta"),
        Arel.sql("SUM(itemvenda.valororiginal * itemvenda.quantidade + (itemvenda.valor_acrescimo - itemvenda.valor_desconto)) AS custo_total")
      )

    dados = linhas.index_by { |mes, _r, _c| mes.to_date.beginning_of_month }

    # Garante os 6 meses mesmo sem vendas (preenche com zero)
    meses = (0..5).map { |i| (5 - i).months.ago.beginning_of_month.to_date }
    labels = []
    receitas = []
    custos = []
    meses.each do |mes|
      linha = dados[mes]
      labels << I18n.l(mes, format: '%b/%y').capitalize
      receitas << (linha ? linha[1].to_f.round(2) : 0.0)
      custos << (linha ? linha[2].to_f.round(2) : 0.0)
    end

    { labels: labels, receitas: receitas, custos: custos }
  end

  # Resumo de comissões do colaborador logado (último período).
  def comissoes
    periodo = CommissionPeriod
      .for_funcionario(@cod_funcionario)
      .for_empresa(@cod_empresa)
      .order(start_date: :desc)
      .first

    return { periodo: nil } unless periodo

    {
      periodo: periodo,
      total_vendas: periodo.total_sales || 0,
      comissao: periodo.commission_amount || 0,
      liquido: periodo.net_commission || 0,
      status: periodo.status
    }
  end

  # Aniversariantes dos próximos 7 dias (hoje..hoje+6) entre clientes que já
  # compraram na empresa logada. Mesma regra do relatório de aniversariantes.
  def aniversariantes
    hoje = Date.current
    fim = hoje + 6

    ini_key = hoje.month * 100 + hoje.day
    fim_key = fim.month * 100 + fim.day
    aniv = "(EXTRACT(MONTH FROM p.dtnascimento) * 100 + EXTRACT(DAY FROM p.dtnascimento))"
    intervalo = ini_key <= fim_key ? "#{aniv} BETWEEN #{ini_key} AND #{fim_key}" : "(#{aniv} >= #{ini_key} OR #{aniv} <= #{fim_key})"

    sql = <<~SQL
      SELECT p.cod_pessoa, p.nome, p.celular, p.telefone, p.dtnascimento
      FROM pessoa p
      JOIN venda v
        ON v.cod_pessoa = p.cod_pessoa
       AND v.cod_empresa = :cod_empresa
       AND v.tipo = 'V'
       AND v.cancelada = false
      WHERE p.dtnascimento IS NOT NULL
        AND #{intervalo}
      GROUP BY p.cod_pessoa, p.nome, p.celular, p.telefone, p.dtnascimento
      ORDER BY EXTRACT(MONTH FROM p.dtnascimento), EXTRACT(DAY FROM p.dtnascimento), p.nome
      LIMIT 50
    SQL

    lista = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.sanitize_sql_array([sql, { cod_empresa: @cod_empresa }])
    )
    { lista: lista }
  end
end
