class CollaboratorsBackoffice::WelcomeController < CollaboratorsBackofficeController

    def index
      agente = request.user_agent

      @dispositivo = 
      if agente =~ /Windows|Macintosh/
        'Computador'
      else
        'Outro'
      end
      
      # Vendas do dia
      @vendas_dia = Venda.where("DATE(datavenda) = ? AND cod_empresa = ?  AND CANCELADA = false ", Date.current, current_collaborator.cod_empresa)
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
        .where("DATE_PART('month', venda.datavenda) = ? AND DATE_PART('year', venda.datavenda) = ? AND venda.cod_empresa = ? and venda.tipo = 'V'  AND CANCELADA = false ", 
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
         AND CANCELADA = false 
         AND cod_funcionario = ? 
         AND cancelada = false",
        Date.current.month, Date.current.year, current_collaborator.cod_empresa, current_collaborator.cod_funcionario
      ).sum(:valortotal) || 0

      @total_vendas_empresa = Venda.where(
        "DATE_PART('month', datavenda) = ? 
         AND DATE_PART('year', datavenda) = ? 
         AND cod_empresa = ? 
         AND CANCELADA = false 
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
#    mudar para os 5 que estão com estoque minimo 

      cod_empresa = current_collaborator.cod_empresa
      @estoque_minimo = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array([
          "
          
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

          -- 🔥 CORRIGIDO
          LEFT JOIN itens_pedido_compras ipc 
            ON ipc.cod_produto = ep.cod_produto 
            AND ipc.cod_cor = ep.cod_cor

          LEFT JOIN pedidos_compras pc 
            ON pc.id = ipc.pedidos_compra_id
            AND pc.cod_empresa = ep.cod_empresa

          -- vendas
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
            p.cod_produto,
            ep.cod_cor,
            p.nome,
            c.nmcor,
            ep.quantidademinima,
            ep.quantidade

          HAVING ep.quantidademinima >= (
            ep.quantidade + COALESCE(SUM(ipc.quantidade), 0)
          )

          ORDER BY vendido_3_meses DESC
          LIMIT 5;

          ",
          cod_empresa
        ])
      )

    end
    private

    def definir_dispositivo
      agente = request.user_agent

      @dispositivo =
        if agente =~ /Windows|Macintosh/
          'Computador'
        elsif agente =~ /iPad/
          'iPad'
        elsif agente =~ /iPhone|Android/
          'Celular'
        else
          'Desconhecido'
        end
    end
end