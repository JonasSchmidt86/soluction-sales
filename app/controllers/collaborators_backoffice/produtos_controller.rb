class CollaboratorsBackoffice::ProdutosController < CollaboratorsBackofficeController


    before_action :set_produto, only: [:edit, :update, :destroy, :show]
    #before_action :get_produto, only: [:new, :edit, :update,]

    def index
        @produtos = Produto.order('cod_produto').all.page(params[:page])
    end
    
    def update
        if @produto.update(params_produto.except(:imagens))
          redirect_to collaborators_backoffice_produtos_path, notice: "Produto atualizado com sucesso!"
        else
          render :edit
        end
    end

    # editar para desativar o item para não aparecer mais 
    def edit
    end

    def new
        @produto = Produto.new 
        @produto.cod_produto = Produto.last.cod_produto += 1
    end

    def create
        @produto = Produto.new(params_produto)

        if @produto.cod_produto.blank?
            @produto.cod_produto = Produto.last.cod_produto += 1
        end
        if @produto.save
            redirect_to collaborators_backoffice_produtos_path, notice: "Produto Cadastrado com sucesso!"
        else 
            render :new
        end
    end
    
    def remover_imagem
        @produto = Produto.find(params[:id])
        imagem = @produto.imagens.find(params[:imagem_id])  # Encontra a imagem associada ao produto
        imagem.purge  # Remove a imagem
    
        redirect_to collaborators_backoffice_imagens_path, notice: "Imagem removida com sucesso."
    end

    def destroy
        if @produto.itenscompra.blank? && @produto.itensvenda.blank? && @produto.empresaprodutos.blank?
            if @produto.destroy
                redirect_to collaborators_backoffice_produtos_path(params[:page]) , notice: "Produto Removido!"
            else
                redirect_to collaborators_backoffice_produtos_path(params[:page]) , notice: "Erro ao remover produto!"
            end
        else
            puts params[:page]
            @produto.ativo = false;
            if @produto.save
                redirect_to collaborators_backoffice_produtos_path(params[:page]), notice: "Produto foi desativado!"
            else 
                redirect_to collaborators_backoffice_produtos_path(params[:page]), notice: "Produto não pode ser removido!"
            end
        end
    end

    def show
    end

    def estoque
        produto = Produto.find(params[:id])
        
        dados = produto.empresaprodutos.where("quantidade <> 0").map do |ep|
            {
            id_empresa: ep.cod_empresa,
            nome_produto: produto.nome,
            cor: "#{ep.cod_cor} - #{ep.cor.nmcor}",
            quantidade: ep.quantidade.to_i
            }
        end
        
        render json: dados
    end

      
    private 

    def params_produto
        params.require(:produto).permit(:cod_produto, :nome, :ncm, :ucom, :cfop, :ativo, :cest, :cod_margem, :grupo, :marca, imagens: [] )
    end

    def set_produto
        @produto = Produto.find(params[:id])
        # @item_venda = ItemVenda.find(cod_produto: @produto.cod_produto )
        # @produtosEmpresa = EmpresaProduto.where('cod_produto = ' params[:id])
    end
        
end
