class CollaboratorsBackoffice::Report::RepSugestaoCompraController < CollaboratorsBackofficeController

  def index
    @meses    = params[:meses].present? ? params[:meses].to_i.clamp(1, 24) : 3
    @qtd_min  = params[:qtd_min].present? ? params[:qtd_min].to_i : 1

    sql = <<~SQL
      SELECT
        ep.cod_produto,
        ep.cod_cor,
        p.nome,
        c.nmcor,
        m.nome AS nome_marca,
        v.total_vendido,
        ep.quantidade AS estoque,
        ep.quantidademinima,
        CEIL(v.total_vendido / #{@meses}.0) AS media_mensal,
        CEIL((v.total_vendido / #{@meses}.0) * 2) AS sugestao_compra,
        uf.cod_pessoa AS ultimo_fornecedor_id,
        COALESCE(ped.quantidade_pedida, 0) AS quantidade_pedida
      FROM empresaproduto ep
      JOIN produto p ON p.cod_produto = ep.cod_produto
      JOIN cores c ON c.cod_cor = ep.cod_cor
      JOIN marca m ON m.cod_marca = p.marca
      LEFT JOIN LATERAL (
        SELECT co.cod_pessoa
        FROM itemcompra ic
        JOIN compra co ON ic.cod_compra = co.cod_compra
        WHERE ic.cod_produto = ep.cod_produto
          AND co.cod_empresa = ep.cod_empresa
          AND co.cod_pessoa IS NOT NULL
        ORDER BY co.datacompra DESC
        LIMIT 1
      ) uf ON TRUE
      LEFT JOIN LATERAL (
        SELECT SUM(ipc.quantidade) AS quantidade_pedida
        FROM itens_pedido_compras ipc
        JOIN pedidos_compras pc ON pc.id = ipc.pedidos_compra_id
        WHERE ipc.cod_produto = ep.cod_produto
          AND ipc.cod_cor = ep.cod_cor
          AND pc.cod_empresa = ep.cod_empresa
          AND pc.data_entrega IS NULL
      ) ped ON TRUE
      JOIN (
        SELECT
          iv.cod_empresa,
          iv.cod_produto,
          iv.cod_cor,
          SUM(iv.quantidade) AS total_vendido
        FROM itemvenda iv
        JOIN venda v ON v.cod_venda = iv.cod_venda AND v.tipo = 'V' AND v.cancelada = false
        WHERE v.datavenda >= CURRENT_DATE - INTERVAL '#{@meses} months'
        GROUP BY iv.cod_empresa, iv.cod_produto, iv.cod_cor
      ) v ON v.cod_empresa = ep.cod_empresa
          AND v.cod_produto = ep.cod_produto
          AND v.cod_cor = ep.cod_cor
      WHERE ep.cod_empresa = ?
        AND ep.quantidade = 0
        AND v.total_vendido > #{@qtd_min}
        AND ep.ativo = true
        #{filtro_marca}
        #{filtro_produto}
      ORDER BY v.total_vendido DESC
    SQL

    binds = [current_collaborator.cod_empresa]
    binds << params[:cod_marca].to_i if params[:cod_marca].present?
    binds << "%#{params[:term]}%" if params[:term].present?

    @produtos = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([sql, *binds])
    )
  end

  def add_to_order
    cod_produto    = params[:cod_produto]
    cod_cor        = params[:cod_cor]
    cod_fornecedor = params[:cod_fornecedor]

    @pedido = PedidosCompra.where(cod_pessoa: cod_fornecedor, data_entrega: nil, cod_empresa: current_collaborator.cod_empresa)
                           .order(data_emissao: :desc).first

    pedido_novo = false
    if @pedido.nil?
      @pedido = PedidosCompra.new(cod_pessoa: cod_fornecedor, data_emissao: Date.current)
      @pedido.cod_empresa = current_collaborator.cod_empresa
      pedido_novo = true
    else
      itempedido = @pedido.itens_pedido_compras.where(cod_produto: cod_produto, cod_cor: cod_cor).first
    end

    valor_unitario = Itemcompra.joins(:compra)
                               .where(cod_produto: cod_produto, cod_cor: cod_cor)
                               .order('compra.datacompra DESC')
                               .limit(1)
                               .pick(:valorunitario) || 1.0

    if itempedido
      itempedido.quantidade += 1
      itempedido.valor_total = itempedido.valor_unitario * itempedido.quantidade
      unless itempedido.save
        flash[:error] = "Erro ao atualizar item: #{itempedido.errors.full_messages.join(', ')}"
        redirect_to collaborators_backoffice_report_sugestao_compra_path(params.permit(:meses, :qtd_min, :term, :cod_marca)) and return
      end
    else
      item = ItensPedidoCompra.new(
        cod_produto: cod_produto, cod_cor: cod_cor,
        quantidade: 1, valor_unitario: valor_unitario,
        percentual_ipi: 0.0, percentual_icms: 0.0, valor_total: valor_unitario
      )
      @pedido.itens_pedido_compras << item
    end

    @pedido.total = @pedido.itens_pedido_compras.sum { |i| i.valor_total.to_f }

    if @pedido.save
      produto    = Produto.find_by(cod_produto: cod_produto)
      fornecedor = Pessoa.find_by(cod_pessoa: cod_fornecedor)
      msg = pedido_novo ? "Novo pedido criado para #{fornecedor&.nome} com #{produto&.nome}" \
                        : "Produto #{produto&.nome} adicionado ao pedido #{@pedido.nr_pedido}"
      flash[:notice] = msg
    else
      flash[:error] = "Erro ao salvar: #{@pedido.errors.full_messages.join(', ')}"
    end

    redirect_to collaborators_backoffice_report_sugestao_compra_path(params.permit(:meses, :qtd_min, :term, :cod_marca))
  end

  private

  def filtro_marca
    params[:cod_marca].present? ? "AND m.cod_marca = ?" : ""
  end

  def filtro_produto
    params[:term].present? ? "AND p.nome ILIKE ?" : ""
  end

end
