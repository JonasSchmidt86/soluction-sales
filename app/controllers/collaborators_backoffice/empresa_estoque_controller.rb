class CollaboratorsBackoffice::EmpresaEstoqueController < CollaboratorsBackofficeController
    
    before_action :set_produto, only: [:destroy, :edit]

    def index
        
        consulta = " empresaproduto.ativo = true ";

        if !params[:term].blank?
            consulta += " and produto.cod_produto::varchar = REPLACE(TRIM('"+ params[:term] +"%'), \'%\', \'\') OR produto.nome ILIKE '"+ params[:term] +"%'";
        end

        if !params[:contem].blank?
            if params[:contem] == '1'
                consulta += " and empresaproduto.quantidade != 0 "
            end
        else 
            unless params.present? && params.key?(:contem) && params.key?(:cod_empresa) && params.key?(:term) && params.key?(:cod_produto)
                consulta += " and empresaproduto.quantidade != 0 "
            end
        end

        if !params[:cod_empresa].blank?
            consulta += " and empresaproduto.cod_empresa = "+params[:cod_empresa] + " "
        end

        per_page = params[:per_page].present? ? params[:per_page].to_i : 30
        if params[:per_page].present? && params[:per_page].to_i === 0
            @empresa_produtos = Empresaproduto.select("empresaproduto.*").joins(:produto).order("produto.nome ASC, empresaproduto.cod_empresa asc").where(consulta);
        else
            @empresa_produtos = Empresaproduto.select("empresaproduto.*").joins(:produto).order("produto.nome ASC, empresaproduto.cod_empresa asc").where(consulta).page(params[:page]).per(per_page);
        end

    end

    def edit 
        @empresa_produto

        @estoque = Empresaproduto.where("cod_produto = ? and (ativo = true or quantidade > 0 )", @empresa_produto.cod_produto ).
                    order("cod_empresa,cod_cor desc, quantidade desc");
        puts @estoque.size;
    end

    def destroy
        if !@empresa_produto.blank?
            @empresa_produto.ativo = false
            if @empresa_produto.save
                redirect_to collaborators_backoffice_empresa_estoque_index_path, notice: "Produto Inativado!"
            end
        end 
    end 
    
    private 

    def set_produto
        @empresa_produto = Empresaproduto.find(params[:id])
    end

end
