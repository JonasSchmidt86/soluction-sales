class CollaboratorsBackoffice::Report::RepDreController < CollaboratorsBackofficeController
  
  def index

    if params[:dataInicial].blank?
      params[:dataInicial] = Time.current.strftime("01/%m/%Y")
    end 
    if params[:dataFinal].blank?
      params[:dataFinal] = Date.today.end_of_month.strftime("%d/%m/%Y")
    end

    @vendas = Venda.joins(:itensvenda)
      .where("venda.cod_empresa = ? and venda.tipo = 'V' and date(venda.datavenda) between to_date(?, 'DD/MM/YYYY') and to_date(?, 'DD/MM/YYYY') and venda.cancelada = false", current_collaborator.cod_empresa, params[:dataInicial], params[:dataFinal])
      .group("mes")
      .select(
        Arel.sql("extract('month' from venda.datavenda) AS mes"),
        Arel.sql("SUM(itemvenda.valorunitario * itemvenda.quantidade) AS receita_bruta"),
        Arel.sql("SUM(itemvenda.valororiginal * itemvenda.quantidade) AS custo_total")
      )
      .order(Arel.sql("mes"))

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
