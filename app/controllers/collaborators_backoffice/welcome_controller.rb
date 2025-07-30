class CollaboratorsBackoffice::WelcomeController < CollaboratorsBackofficeController

    def index
      # Vendas do dia
      @vendas_dia = Venda.where("DATE(datavenda) = ? AND cod_empresa = ?", Date.current, current_collaborator.cod_empresa)
      @total_vendas_dia = @vendas_dia.sum(:valortotal)
      @qtd_vendas_dia = @vendas_dia.count
      
      # Última venda
      @ultima_venda = Venda.where(cod_empresa: current_collaborator.cod_empresa)
                      .where("date(venda.datavenda) = ? AND TIPO = 'V' AND CANCELADA = false ", Time.current).sum(:valortotal) || 0
      
      # Caixa
      @caixa_atual = Caixa.where(datafechamento: nil, cod_empresa: current_collaborator.cod_empresa).first
      @entradas_caixa = @caixa_atual&.valorentradas || 0
      @saidas_caixa = @caixa_atual&.valorsaidas || 0
      @abertura_caixa = @caixa_atual&.valorabertura || 0
      @saldo_caixa = @abertura_caixa + @entradas_caixa - @saidas_caixa
      
      # Último fechamento de caixa
      @ultimo_fechamento = Caixa.where(cod_empresa: current_collaborator.cod_empresa)
                               .where.not(datafechamento: nil)
                               .order(datafechamento: :desc)
                               .first
      
      # 5 produtos mais vendidos do mês
      @produtos_mais_vendidos = Itemvenda.joins(:venda, :produto)
        .where("DATE_PART('month', venda.datavenda) = ? AND DATE_PART('year', venda.datavenda) = ? AND venda.cod_empresa = ? and venda.tipo = 'V'", 
               Date.current.month, Date.current.year, current_collaborator.cod_empresa)
        .group("produto.nome, produto.cod_produto")
        .order("SUM(itemvenda.quantidade) DESC")
        .select("produto.nome, produto.cod_produto, SUM(itemvenda.quantidade) as total_vendido")
        .limit(6)
        
      @vendas_vendedor = Venda.where(
        "DATE_PART('month', datavenda) = ?
         AND DATE_PART('year', datavenda) = ? 
         AND cod_empresa = ? 
         AND tipo = 'V'
         AND cod_funcionario = ? 
         AND cancelada = false",
        Date.current.month, Date.current.year, current_collaborator.cod_empresa, current_collaborator.cod_funcionario
      ).sum(:valortotal) || 0

      @total_vendas_empresa = Venda.where(
        "DATE_PART('month', datavenda) = ? 
         AND DATE_PART('year', datavenda) = ? 
         AND cod_empresa = ? 
         AND tipo = 'V' 
         AND cancelada = false",
        Date.current.month, Date.current.year, current_collaborator.cod_empresa
      ).sum(:valortotal) || 0

      @total_pagar = Contaspagrec.where(
        "DATE_PART('month', dtvencimento) = ? 
         AND DATE_PART('year', dtvencimento) = ? 
         AND cod_empresa = ? 
         AND cod_venda is null
         AND quitada = false",
        Date.current.month, Date.current.year, current_collaborator.cod_empresa
      ).sum(:valorparcela) || 0

      @total_receber = Contaspagrec.where(
        "DATE_PART('month', dtvencimento) = ? 
         AND DATE_PART('year', dtvencimento) = ? 
         AND cod_empresa = ? 
         AND cod_venda is not null
         AND ativo = true
         AND quitada = false",
        Date.current.month, Date.current.year, current_collaborator.cod_empresa
      ).sum(:valorparcela) || 0
        
      # 5 produtos mais lucrativos do mês
      @produtos_mais_lucrativos = Itemvenda.joins(:venda, :produto)
        .where(
          "DATE_PART('month', venda.datavenda) = ? AND DATE_PART('year', venda.datavenda) = ? AND venda.cod_empresa = ? AND venda.tipo = 'V' AND itemvenda.valororiginal > 0",
          Date.current.month, Date.current.year, current_collaborator.cod_empresa
        )
        .group("produto.cod_produto")
        .select(
          "MIN(produto.nome) AS nome,
          produto.cod_produto,
          SUM(((itemvenda.quantidade * itemvenda.valorunitario) + itemvenda.valor_acrescimo - itemvenda.valor_desconto) - (itemvenda.quantidade * itemvenda.valororiginal)) AS lucro_total"
        )
        .order("lucro_total DESC")
        .limit(6)

    end
end