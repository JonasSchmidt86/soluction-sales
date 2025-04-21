
class CollaboratorsBackoffice::ProdutoImagensController < CollaboratorsBackofficeController

  before_action :set_produto, only: [:create]
  before_action :set_produto_imagem, only: [:destroy, :update_ordem, :toggle_principal]
  
  def index
    # @produto_imagens = ProdutoImagem.all.order(created_at: :desc).page(params[:page])
    query = params[:term]
    @produto_imagens = ProdutoImagem.joins(:produto)
                      .where('produto_imagens.cod_produto::varchar = REPLACE(TRIM(:query), \'%\', \'\') OR 
                              produto.nome ILIKE :query', query: "%#{query}%")
                      .where(params[:cod_cor].present? ? ["cod_cor = ?", params[:cod_cor]] : nil)
                      .order(:cod_produto, :cod_cor)
                      .page(params[:page])

  end


  def edit
    @produto = params[:id].present? ? Produto.find(params[:id]) : Produto.new
    if params[:id].present? && params[:id] == "0"
      @produto = Produto.new
    elsif params[:id].present?
      if @produto.nil?
        @produto_imagens = ProdutoImagem.new
      else
        @produto_imagens = @produto.produto_imagens.ordenadas
        .page(params[:page])
      end
    end
  end
  
  def create
    if params[:cod_cor].present?
      @cor = Core.find(params[:cod_cor])
    else 
      @cor = Core.first
    end
  
    # Verifique se as imagens estão presentes
    if params[:imagens].present?
      if @produto.blank?
        redirect_to edit_collaborators_backoffice_produto_imagen_path(0,params.to_unsafe_h), notice: 'Produto não encontrado!'
        return
      end
      params[:imagens].each do |imagem|
        next if imagem.blank?

        # Crie a instância de ProdutoImagem
        produto_imagem = ProdutoImagem.new
        produto_imagem.produto = @produto
        produto_imagem.cor = @cor

        # Gere o nome do arquivo com base no nome do produto
        
        nome_imagem = "#{@produto.nome.split(' ')[0..1].join(' ')}_#{imagem.original_filename.split('.').first}.#{imagem.original_filename}"
        
        # Abrir a imagem com MiniMagick
        imagem_processada = MiniMagick::Image.read(imagem.tempfile)
        imagem_processada.resize "1920x1080" # Ajuste as dimensões conforme necessário

        # Anexando a imagem ao modelo
        produto_imagem.imagem.attach(
            io: StringIO.open(imagem_processada.to_blob),
            filename: nome_imagem,
            content_type: imagem.content_type,
            key: nome_imagem
          )

        # produto_imagem.imagem.attach(io: imagem.tempfile, filename: nome_imagem, key: nome_imagem)

        @produto.produto_imagens << produto_imagem
        
        produto_imagem.save

      end

      if params[:path].present? 
        path = edit_collaborators_backoffice_produto_imagen_path(@produto.cod_produto)
      else
        path = collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto)
      end

      redirect_to path, notice: 'Imagens associadas ao produto foram salvas com sucesso!'

    else
      redirect_to path, alert: 'Nenhuma imagem foi selecionada!'
    end
  rescue ActiveRecord::Rollback => e
    # Caso ocorra um erro, redireciona com a mensagem de erro
    redirect_to collaborators_backoffice_produto_imagens_path, alert: "Falha ao salvar imagens: #{e.message}"
  end

  # para apagar o registro de produto_imagem com todas as imagens junto
  def destroy
    # Remove a imagem do ActiveStorage antes de excluir o registro
    @produto_imagem.imagem.purge if @produto_imagem.imagem.attached?

    if params[:term].present?
      path = edit_collaborators_backoffice_produto_imagen_path(@produto_imagem.produto.cod_produto)
    else
      path = collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto)
    end

    if @produto_imagem.destroy
      redirect_to path, notice: "Imagem removida com sucesso!"
    else
      redirect_to path, alert: "Falha ao remover imagem!"
    end
  end
  
  def update_ordem
    if @produto_imagem.update(ordem: params[:ordem])
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  def toggle_principal
    if @produto_imagem.update(principal: !@produto_imagem.principal)
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  private
  
  def set_produto
    if params[:cod_produto].present?
      @produto = Produto.find(params[:cod_produto]);
    end
  end
  
  def set_produto_imagem
    @produto_imagem = ProdutoImagem.find(params[:id]);
    @produto = @produto_imagem.produto;
  end
  
  # def produto_imagem_params
  #   params.require(:produto_imagem).permit(:imagens, :cod_produto, :cod_cor, :grupo, :principal);
  # end
end