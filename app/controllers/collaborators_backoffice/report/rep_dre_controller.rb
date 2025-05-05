class CollaboratorsBackoffice::Report::RepDreController < CollaboratorsBackofficeController
  # def index
  #   @periodo_inicio = params[:inicio].present? ? Date.parse(params[:inicio]) : Date.today.beginning_of_month
  #   @periodo_fim = params[:fim].present? ? Date.parse(params[:fim]) : Date.today.end_of_month
  
  #   @receitas = Lancamentoscaixa.where("tipo = 'E' and cod_empresa = ? and date(datapagto) between date(?) and date(?)", current_collaborator.cod_empresa, @periodo_inicio, @periodo_fim)
  #   @despesas = Lancamentoscaixa.where("tipo = 's' and cod_empresa = ? and date(datapagto) between date(?) and date(?)", current_collaborator.cod_empresa, @periodo_inicio, @periodo_fim)
  
  #   @total_receitas = @receitas.sum(:valor)
  #   @total_despesas = @despesas.sum(:valor)
  #   @lucro_liquido = @total_receitas - @total_despesas
  # end
  
  def index
    @vendas = Venda.joins(:itensvenda)
      .where("venda.cod_empresa = 2 and venda.tipo = 'V' and date(venda.datavenda) between date(?) and date(?) and venda.cancelada = false", "2025/03/01", "2025/03/31")
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
              and lancamentoscaixa.cod_empresa = 2 
              and date(lancamentoscaixa.datapagto) between date(?) and date(?)", "2025/03/01", "2025/03/31").
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
