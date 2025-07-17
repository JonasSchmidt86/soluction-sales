class CollaboratorsBackoffice::Report::RepStockMinController < CollaboratorsBackofficeController
  
  def index
    conditions = ["ep.cod_empresa = ?", current_collaborator.cod_empresa]
    
    # Filtro por marca
    if params[:cod_marca].present?
      conditions[0] += " AND p.marca = ?"
      conditions << params[:cod_marca]
    end
    
    # Filtro por grupo
    if params[:cod_grupo].present?
      conditions[0] += " AND p.grupo = ?"
      conditions << params[:cod_grupo]
    end
    
    # Filtro por nome ou código do produto
    if params[:search].present?
      conditions[0] += " AND (UPPER(p.nome) LIKE UPPER(?) OR CONCAT(p.cod_produto, '-', ep.cod_cor) LIKE ?)"
      conditions << "%#{params[:search]}%"
      conditions << "%#{params[:search]}%"
    end
    
    sql = <<~SQL
      SELECT 
        CONCAT(p.cod_produto, '-', ep.cod_cor) AS codigo,
        p.cod_produto,
        ep.cod_cor,
        p.nome,
        c.nmcor,
        ep.quantidademinima AS estoque_minimo,
        ep.quantidade AS estoque,

        uf.cod_pessoa AS ultimo_fornecedor_id,

        -- Quantidade já pedida em pedidos em aberto da empresa
        COALESCE(SUM(ipc.quantidade), 0)::integer AS quantidade_pedida_aberta

      FROM empresaproduto ep
      JOIN produto p ON ep.cod_produto = p.cod_produto
      JOIN cores c ON c.cod_cor = ep.cod_cor

      -- Último fornecedor com LATERAL
      LEFT JOIN LATERAL (
        SELECT co.cod_pessoa
        FROM itemcompra ic
        JOIN compra co ON ic.cod_compra = co.cod_compra
        WHERE ic.cod_produto = p.cod_produto
          AND co.cod_empresa = ep.cod_empresa
          and co.cod_pessoa IS NOT NULL
        ORDER BY co.datacompra DESC
        LIMIT 1
      ) uf ON TRUE

      -- Pedidos em aberto
      LEFT JOIN pedidos_compras pc 
        ON pc.cod_empresa = ep.cod_empresa
        AND pc.data_entrega IS NULL

      LEFT JOIN itens_pedido_compras ipc 
        ON ipc.cod_produto = p.cod_produto 
        AND ipc.cod_cor = ep.cod_cor
        AND ipc.pedidos_compra_id = pc.id

      WHERE #{conditions[0]}
        AND ep.quantidade <= ep.quantidademinima
        AND ep.quantidademinima > 0

      GROUP BY 
        p.cod_produto, ep.cod_cor, p.nome, c.nmcor, ep.quantidademinima, ep.quantidade, uf.cod_pessoa

      ORDER BY p.nome;


    SQL
    
    @stock_items = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql] + conditions[1..-1])
    )
    
    @marcas = Marca.all
    @grupos = Grupo.all
  end
  
  def add_to_order
    cod_produto = params[:cod_produto]
    cod_cor = params[:cod_cor]
    cod_fornecedor = params[:cod_fornecedor]
    
    # Buscar o último pedido em aberto para este fornecedor
    @pedido = PedidosCompra.where(cod_pessoa: cod_fornecedor, data_entrega: nil, cod_empresa: current_collaborator.cod_empresa)
                          .order(data_emissao: :desc).first

    # Se não existir pedido em aberto, criar um novo
    pedido_novo = false
    if @pedido.nil?
      @pedido = PedidosCompra.new(
        cod_pessoa: cod_fornecedor,
        data_emissao: Date.current
      )
      @pedido.cod_empresa = current_collaborator.cod_empresa
      pedido_novo = true
    else
      itempedido = @pedido.itens_pedido_compras.where(cod_produto: cod_produto, cod_cor: cod_cor).first
    end

    valor_unitario = Itemcompra.joins(:compra) # precisa ter relacionamento definido: belongs_to :compra
                               .where(cod_produto: cod_produto, cod_cor: cod_cor)
                               .order('compra.datacompra DESC')
                               .limit(1)
                               .pick(:valorunitario) || 1.0

    if itempedido
      # Se o item já existe, incrementar a quantidade
      itempedido.quantidade += 1
      itempedido.valor_total = itempedido.valor_unitario * itempedido.quantidade

      # Salvar o item atualizado  
      unless itempedido.save
        flash[:error] = "Erro ao atualizar item: #{itempedido.errors.full_messages.join(', ')}"
        redirect_to collaborators_backoffice_report_stock_min_index_path and return
      end
      @pedido.total = @pedido.calcular_total
      puts "Total do pedido atualizado: #{@pedido.total}"
    else
      # vl_total = valor_unitario * (itempedido.quantidade +1)
      item = ItensPedidoCompra.new(
        cod_produto: cod_produto,
        cod_cor: cod_cor,
        quantidade: 1,
        valor_unitario: valor_unitario,
        percentual_ipi: 0.0,
        percentual_icms: 0.0,
        valor_total: valor_unitario
      )
      @pedido.itens_pedido_compras << item
      @pedido.total =+ item.valor_unitario
    end
    
    # Atualizar o total do pedido
    puts "Total do pedido ANTES: #{@pedido.total}"
    if @pedido.save
      # Buscar nome do produto para exibir na mensagem
      produto = Produto.find_by(cod_produto: cod_produto)
      nome_produto = produto ? produto.nome : cod_produto
      
      # Buscar nome do fornecedor para exibir na mensagem
      fornecedor = Pessoa.find_by(cod_pessoa: cod_fornecedor)
      nome_fornecedor = fornecedor ? fornecedor.nome : cod_fornecedor
      
      if pedido_novo
        flash[:success] = "Novo pedido criado para #{nome_fornecedor} com o produto #{nome_produto}"
      else
        flash[:success] = "Produto #{nome_produto} adicionado ao pedido #{@pedido.nr_pedido} de #{nome_fornecedor}"
      end
    else
      Rails.logger.info @pedido.errors.full_messages
      Rails.logger.info @pedido.itens_pedido_compras.map(&:errors).map(&:full_messages)

      flash[:error] = "Erro ao salvar: #{@pedido.errors.full_messages.join(', ')}"
      redirect_to collaborators_backoffice_report_stock_min_index_path and return
    end
    redirect_to collaborators_backoffice_report_stock_min_index_path
  end

  private

  def order_params
    params.permit(:cod_produto, :cod_cor, :cod_fornecedor, :search, :cod_marca, :cod_grupo)
  end
end