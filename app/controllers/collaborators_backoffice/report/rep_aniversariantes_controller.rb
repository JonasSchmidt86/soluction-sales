class CollaboratorsBackoffice::Report::RepAniversariantesController < CollaboratorsBackofficeController

  # Relatório de aniversariantes: clientes que já compraram na empresa logada
  # e cujo aniversário (dia/mês, ignorando o ano) cai no intervalo informado.
  # Padrão: do dia atual até o fim do mês corrente.
  def index
    data_inicial, data_final = parse_periodo

    @data_inicial = data_inicial
    @data_final = data_final

    cod_empresa = current_collaborator.cod_empresa

    # Expressão que compara aniversário (mês*100 + dia) dentro do intervalo.
    # Trata o caso em que o intervalo cruza a virada de ano (ex.: 20/12 a 10/01).
    ini = data_inicial.month * 100 + data_inicial.day
    fim = data_final.month * 100 + data_final.day

    aniv_expr = "(EXTRACT(MONTH FROM p.dtnascimento) * 100 + EXTRACT(DAY FROM p.dtnascimento))"

    intervalo_sql =
      if ini <= fim
        "#{aniv_expr} BETWEEN #{ini} AND #{fim}"
      else
        # intervalo que vira o ano: aniversário >= início OU <= fim
        "(#{aniv_expr} >= #{ini} OR #{aniv_expr} <= #{fim})"
      end

    sql = <<~SQL
      SELECT
        p.cod_pessoa,
        p.nome,
        p.celular,
        p.telefone,
        p.dtnascimento,
        COUNT(DISTINCT v.cod_venda) AS total_compras,
        MAX(v.datavenda) AS ultima_compra,
        COALESCE(SUM(
          CASE WHEN cpr.ativo = true AND cpr.quitada = false AND cpr.cod_venda IS NOT NULL
               THEN cpr.valorparcela ELSE 0 END
        ), 0) AS total_aberto
      FROM pessoa p
      JOIN venda v
        ON v.cod_pessoa = p.cod_pessoa
       AND v.cod_empresa = :cod_empresa
       AND v.tipo = 'V'
       AND v.cancelada = false
      LEFT JOIN contaspagrec cpr
        ON cpr.cod_venda = v.cod_venda
       AND cpr.cod_empresa = :cod_empresa
      WHERE p.dtnascimento IS NOT NULL
        AND #{intervalo_sql}
      GROUP BY p.cod_pessoa, p.nome, p.celular, p.telefone, p.dtnascimento
      ORDER BY EXTRACT(MONTH FROM p.dtnascimento), EXTRACT(DAY FROM p.dtnascimento), p.nome
    SQL

    @aniversariantes = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.sanitize_sql_array([sql, { cod_empresa: cod_empresa }])
    )
  end

  private

  # Lê dataInicial/dataFinal (dd/mm/yyyy). Padrão: hoje até o fim do mês.
  def parse_periodo
    hoje = Time.zone.today

    inicial =
      if params[:dataInicial].present?
        parse_data(params[:dataInicial]) || hoje
      else
        hoje
      end

    final =
      if params[:dataFinal].present?
        parse_data(params[:dataFinal]) || inicial.end_of_month
      else
        inicial.end_of_month
      end

    [inicial, final]
  end

  def parse_data(str)
    Date.strptime(str, '%d/%m/%Y')
  rescue ArgumentError
    nil
  end
end
