class CollaboratorsBackoffice::ProdutosController < CollaboratorsBackofficeController


    before_action :set_produto, only: [:edit, :update, :destroy]
    #before_action :get_produto, only: [:new, :edit, :update,]


    def index
        @produtos = Produto.order('cod_produto').all.page(params[:page])
    end
    
    
    def update
        if @produto.update(params_produto)
            redirect_to collaborators_backoffice_produtos_path, notice: "Produto Cadastrado com sucesso!"
        else
            render :edit  
        end
    end

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

    def destroy
        if @produto.itenscompra.blank? && @produto.itensvenda.blank? && @produto.empresaprodutos.blank?
            if @produto.destroy
                redirect_to collaborators_backoffice_produtos_path , notice: "Produto Removido!"
            else
                redirect_to collaborators_backoffice_produtos_path , notice: "Erro ao remover produto!"
            end
        else
            redirect_to collaborators_backoffice_produtos_path , notice: "Produto não pode ser removido!"
        end
    end

    private 

    def params_produto
        params.require(:produto).permit(:cod_produto, :nome, :ncm, :ucom, :cfop, :ativo, :cest, :cod_margem, :cod_grupo, :cod_marca )
    end

    def set_produto
        @produto = Produto.find(params[:id])
        # @item_venda = ItemVenda.find(cod_produto: @produto.cod_produto )
        # @produtosEmpresa = EmpresaProduto.where('cod_produto = ' params[:id])
    end
        
end
