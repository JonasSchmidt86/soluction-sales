class CollaboratorsBackoffice::PedidosComprasController < CollaboratorsBackofficeController

  before_action :set_pedido, only: [:show, :edit, :update, :destroy]

  def index
    @pedidos = PedidosCompra.includes(:pessoa, :itens_pedido_compras)
                            .where(cod_empresa: current_collaborator.cod_empresa)

    if params[:term].present?
      @pedidos = @pedidos.joins(:pessoa).where('pessoa.nome ILIKE ?', "%#{params[:term]}%")
    end

    if params[:nr_pedido].present?
      @pedidos = @pedidos.where('nr_pedido ILIKE ?', "%#{params[:nr_pedido]}%")
    end

    if params[:dataInicial].present?
      data_inicial = Date.strptime(params[:dataInicial], '%d/%m/%Y')
      @pedidos = @pedidos.where('data_emissao >= ?', data_inicial)
    end

    if params[:dataFinal].present?
      data_final = Date.strptime(params[:dataFinal], '%d/%m/%Y')
      @pedidos = @pedidos.where('data_emissao <= ?', data_final)
    end

    @pedidos = @pedidos.order(data_emissao: :desc).page(params[:page])
  end


  def new
    @pedido = PedidosCompra.new
    @pedido.data_emissao = Date.current
    2.times { @pedido.itens_pedido_compras.build }
  end

  def create
    @pedido = PedidosCompra.new(pedido_params)
    @pedido.cod_empresa = current_collaborator.cod_empresa

    if params[:pedidos_compra][:itens_pedido_compras_attributes].present?
      itens = params[:pedidos_compra][:itens_pedido_compras_attributes].values
      @pedido.itens_pedido_compras.clear
      
      itens.each do |item_params|
        next if item_params[:cod_produto].blank?
        
        item = ItensPedidoCompra.new
        item.cod_produto = item_params[:cod_produto]
        item.cod_cor = item_params[:cod_cor] if item_params[:cod_cor].present?
        item.quantidade = item_params[:quantidade].to_f
        item.valor_unitario = item_params[:valor_unitario].gsub(',', '.').to_f
        item.percentual_ipi = item_params[:percentual_ipi].to_f
        item.percentual_icms = item_params[:percentual_icms].to_f
        
        @pedido.itens_pedido_compras << item
      end
    end

    @pedido.total = @pedido.itens_pedido_compras.sum { |item| item.valor_total || 0 }

    if @pedido.save
      redirect_to collaborators_backoffice_pedidos_compras_path, notice: "Pedido criado com sucesso!"
    else
      render :new
    end
  end

  def show
  end

  def edit
    @pedido.itens_pedido_compras.build if @pedido.itens_pedido_compras.empty?
  end

  def update
    sanitize_valor_unitario_raw_params # <- atua diretamente nos params, sem acessar pedido_params

    if @pedido.update(pedido_params)
      redirect_to collaborators_backoffice_pedidos_compra_path(@pedido), notice: "Pedido atualizado com sucesso!"
    else
      puts "Erros ao atualizar pedido: #{@pedido.errors.full_messages}"
      @pedido.itens_pedido_compras.each do |item|
        puts "Item ##{item.id || 'novo'} erros: #{item.errors.full_messages}" if item.invalid?
      end
      render :edit
    end
  end


  def destroy
    if @pedido.destroy
      redirect_to collaborators_backoffice_pedidos_compras_path, notice: "Pedido excluído com sucesso!"
    else
      redirect_to collaborators_backoffice_pedidos_compras_path, alert: "Erro ao excluir pedido!"
    end
  end

  private

  def sanitize_valor_unitario_raw_params
    return unless params[:pedidos_compra] && params[:pedidos_compra][:itens_pedido_compras_attributes]

    total = 0.0

    params[:pedidos_compra][:itens_pedido_compras_attributes].each do |_, item|
      next if item[:valor_unitario].blank? || item[:cod_produto].blank?

      # Substitui vírgula e ponto corretamente para decimal
      valor_unitario = item[:valor_unitario].gsub('.', '').gsub(',', '.').to_f
      quantidade = item[:quantidade].to_f rescue 0

      item[:valor_unitario] = valor_unitario
      item[:valor_total] = valor_unitario * quantidade;

      total += (valor_unitario * quantidade)
    end

    params[:pedidos_compra][:total] = total.round(2)
  end



  def set_pedido
    @pedido = PedidosCompra.find(params[:id])
  end

  def pedido_params
    params.require(:pedidos_compra).permit(
      :cod_pessoa, :nr_pedido, :data_emissao, :data_entrega, :observacoes, :total,
      itens_pedido_compras_attributes: [:id, :cod_produto, :cod_cor, :quantidade, :valor_unitario, :valor_total,
                                       :percentual_ipi, :percentual_icms, :_destroy]
    )
  end
end