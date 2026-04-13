class RelatorioProdutosMaisVendidosService
  def self.call(params, empresa_id)
    new(params, empresa_id).call
  end

  def initialize(params, empresa_id)
    @params = params
    @empresa_id = empresa_id
  end

  def call
    sql, binds = montar_query
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, *binds])
    )
  end

  private

  def montar_query
    filtros = []
    binds = []

    # empresa (fixo)
    filtros << "vw_produtos_mais_vendidos.cod_empresa = ?"
    binds << @empresa_id

    # produto (código ou nome)
    if @params[:produto].present?
      filtros << "(vw_produtos_mais_vendidos.cod_produto::varchar = REPLACE(TRIM(?), '%', '') OR nome_produto ILIKE ?)"
      binds << @params[:produto]
      binds << "#{@params[:produto]}%"
    end

    # grupo
    if @params[:cod_grupo].present?
      filtros << "p.GRUPO = ?"
      binds << @params[:cod_grupo].to_i
    end

    # marca
    if @params[:cod_marca].present?
      filtros << "p.MARCA = ?"
      binds << @params[:cod_marca].to_i
    end

    # período
    if @params[:dataInicial].present? && @params[:dataFinal].present?
      filtros << "DATE(datavenda) BETWEEN TO_DATE(?, 'DD/MM/YYYY') AND TO_DATE(?, 'DD/MM/YYYY')"
      binds << @params[:dataInicial]
      binds << @params[:dataFinal]
    end

    sql = <<~SQL
      SELECT
        vw_produtos_mais_vendidos.cod_produto,
        nome_produto,
        nome_cor,
        CAST(SUM(quantidade_vendida) AS integer) AS total_quantidade,
        formata_moeda_brasil(SUM(valor_total_vendido)) AS total_valor,
        formata_moeda_brasil(SUM(valor_total_custo)) AS custo_total,
        formata_moeda_brasil(SUM(valor_total_vendido) - SUM(valor_total_custo)) AS lc_bruto
      FROM vw_produtos_mais_vendidos
      INNER JOIN produto p ON p.cod_produto = vw_produtos_mais_vendidos.cod_produto
      INNER JOIN grupo g ON g.cod_grupo = p.grupo
      INNER JOIN marca m ON m.cod_marca = p.marca
      WHERE #{filtros.join(" AND ")}
      GROUP BY vw_produtos_mais_vendidos.cod_produto, nome_produto, nome_cor
      ORDER BY total_quantidade DESC
    SQL

    [sql, binds]
  end
end

