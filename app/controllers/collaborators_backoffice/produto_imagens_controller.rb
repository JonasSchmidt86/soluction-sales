
class CollaboratorsBackoffice::ProdutoImagensController < CollaboratorsBackofficeController

  before_action :set_produto, only: [:create]
  before_action :set_produto_imagem, only: [:destroy, :update_ordem, :toggle_principal]
  
  def index
    
    @produto_imagens = ProdutoImagem.all.order(created_at: :desc).page(params[:page])


    # aqui ele deveria trazer todas as imagens dos produtos
    @produto = params[:cod_produto].present? ? Produto.find(params[:cod_produto]) : Produto.new
    if @produto.nil?
      @produto_imagens = ProdutoImagem.new
    else
      @produto_imagens = @produto.produto_imagens.ordenadas
    end
    # @produto_imagens = @produto.produto_imagens.order(created_at: :desc)
  end

  def edit
    @produto = params[:id].present? ? Produto.find(params[:id]) : Produto.new
    if @produto.nil?
      @produto_imagens = ProdutoImagem.new
    else
      @produto_imagens = @produto.produto_imagens.ordenadas
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

      params[:imagens].each do |imagem|
        next if imagem.blank?

        # Crie a instância de ProdutoImagem
        produto_imagem = ProdutoImagem.new
        produto_imagem.produto = @produto
        produto_imagem.cor = @cor

        # Gere o nome do arquivo com base no nome do produto
        
        nome_imagem = "#{@produto.nome.split(' ')[0..1].join(' ')}_#{imagem.original_filename.split('.').first}.#{imagem.original_filename.split('.').last}"
        
        puts "Nome da imagem: #{nome_imagem} ---------------------"
        # Anexando a imagem ao modelo
        produto_imagem.imagem.attach(io: imagem.tempfile, filename: nome_imagem, key: nome_imagem)
        @produto.produto_imagens << produto_imagem
        
        produto_imagem.save

      end

      redirect_to collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto), notice: 'Imagens associadas ao produto foram salvas com sucesso!'

    else
      redirect_to collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto), alert: 'Nenhuma imagem foi selecionada!'
    end
  rescue ActiveRecord::Rollback => e
    # Caso ocorra um erro, redireciona com a mensagem de erro
    redirect_to collaborators_backoffice_produto_imagens_path, alert: "Falha ao salvar imagens: #{e.message}"
  end

  # para apagar o registro de produto_imagem com todas as imagens junto
  def destroy
    # Remove a imagem do ActiveStorage antes de excluir o registro
    @produto_imagem.imagem.purge if @produto_imagem.imagem.attached?

    if @produto_imagem.destroy
    # Redirecionar ou renderizar conforme necessário
      redirect_to collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto), notice: "Imagem removida com sucesso!"
    else
      redirect_to collaborators_backoffice_produto_imagens_path, alert: "Falha ao remover imagem!"
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
    @produto = Produto.find(params[:cod_produto]);
  end
  
  def set_produto_imagem
    @produto_imagem = ProdutoImagem.find(params[:id]);
    @produto = @produto_imagem.produto;
  end
  
  # def produto_imagem_params
  #   params.require(:produto_imagem).permit(:imagens, :cod_produto, :cod_cor, :grupo, :principal);
  # end
end