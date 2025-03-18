module CollaboratorsBackoffice
  class ProdutoImagensController < CollaboratorsBackofficeController
    
    before_action :set_produto, only: [:create]
    before_action :set_produto_imagem, only: [:destroy, :update_ordem, :toggle_principal]
    
    def index
      @produto = Produto.find(2909)
      @produto_imagens = @produto.produto_imagens.order(created_at: :desc)
    end
    
    
    def create
      @produto_imagem = @produto.produto_imagens.build(produto_imagem_params)
      
      if @produto_imagem.save
        redirect_to collaborators_backoffice_produto_path(@produto), notice: 'Imagem adicionada com sucesso!'
      else
        redirect_to collaborators_backoffice_produto_path(@produto), alert: 'Erro ao adicionar imagem.'
      end
    end
    
    def destroy
      if @produto_imagem.destroy
        redirect_to collaborators_backoffice_produto_path(@produto), notice: 'Imagem removida com sucesso!'
      else
        redirect_to collaborators_backoffice_produto_path(@produto), alert: 'Erro ao remover imagem.'
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
      @produto = Produto.find(params[:produto_id])
    end
    
    def set_produto_imagem
      @produto_imagem = @produto.produto_imagens.find(params[:id])
    end
    
    def produto_imagem_params
      params.require(:produto_imagem).permit(:imagem, :grupo, :principal)
    end
  end
end 