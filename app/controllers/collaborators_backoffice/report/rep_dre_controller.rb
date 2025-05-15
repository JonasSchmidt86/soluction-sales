class CollaboratorsBackoffice::Report::RepDreController < CollaboratorsBackofficeController
  
  def index

    if params[:dataInicial].blank?
      params[:dataInicial] = Time.current.strftime("01/%m/%Y")
    end 
    if params[:dataFinal].blank?
      params[:dataFinal] = Date.today.end_of_month.strftime("%d/%m/%Y")
    end

    vendas_totais = Venda
      .where(cod_empresa: current_collaborator.cod_empresa)
      .where(tipo: 'V')
      .where(cancelada: false)
      .where("venda.datavenda BETWEEN to_date(?, 'DD/MM/YYYY') AND to_date(?, 'DD/MM/YYYY')", params[:dataInicial], params[:dataFinal])
      .group("extract(month from venda.datavenda)")
      .select(
        Arel.sql("extract(month from venda.datavenda) AS mes"),
        Arel.sql("SUM(venda.valortotal) AS total"),
        Arel.sql("SUM(venda.acrescimo) AS acrescimo"),
        Arel.sql("SUM(venda.desconto) AS desconto")
      )
    itens_totais = Venda
      .joins(:itensvenda)
      .where(cod_empresa: current_collaborator.cod_empresa)
      .where(tipo: 'V')
      .where(cancelada: false)
      .where("venda.datavenda BETWEEN to_date(?, 'DD/MM/YYYY') AND to_date(?, 'DD/MM/YYYY')", params[:dataInicial], params[:dataFinal])
      .group("extract(month from venda.datavenda)")
      .select(
        Arel.sql("extract(month from venda.datavenda) AS mes"),
        Arel.sql("SUM(itemvenda.valorunitario * itemvenda.quantidade) AS receita_bruta"),
        Arel.sql("SUM(itemvenda.valororiginal * itemvenda.quantidade) AS custo_total")
      )
      
    vendas_hash = vendas_totais.index_by { |v| v.mes.to_i }
    itens_hash = itens_totais.index_by { |i| i.mes.to_i }

    @vendas = vendas_hash.keys.sort.map do |mes|
      venda = vendas_hash[mes]
      item  = itens_hash[mes]

      OpenStruct.new(
        mes: mes,
        total: venda.total.to_f,
        acrescimo: venda.acrescimo.to_f,
        desconto: venda.desconto.to_f,
        receita_bruta: item&.receita_bruta.to_f,
        custo_total: item&.custo_total.to_f
      )
    end

    @lancamentos = Lancamentoscaixa.joins(:historico)
      .where("lancamentoscaixa.cancelada = false 
              and lancamentoscaixa.cod_tphitorico != 15 
              and lancamentoscaixa.cod_empresa = ? 
              and date(lancamentoscaixa.datapagto) between to_date(?, 'DD/MM/YYYY') and to_date(?, 'DD/MM/YYYY') ", current_collaborator.cod_empresa, params[:dataInicial], params[:dataFinal]).
       order("lancamentoscaixa.tipo")
      .group("extract('month'from lancamentoscaixa.datapagto)", "tiposhistoricoscaixa.descricao", "lancamentoscaixa.tipo")
      .select(
        Arel.sql("extract('month'from lancamentoscaixa.datapagto) AS mes"),
        Arel.sql("tiposhistoricoscaixa.descricao"),
        Arel.sql("lancamentoscaixa.tipo"),
        Arel.sql("SUM(valor) AS total")
      )
  end

end
