class CollaboratorsBackoffice::EmpresaEstoqueController < CollaboratorsBackofficeController
    
    before_action :set_produto, only: [:destroy]

    def index
        
        consulta = " ativo = true ";

        unless params.present? && params.key?(:contem) && params.key?(:cod_empresa) && params.key?(:term) && params.key?(:cod_produto)
            consulta += " and quantidade != 0 "
        end

        if !params[:contem].blank?
            if params[:contem] == '1'
            #     consulta += " and quantidade is not null "
            # else 
                consulta += " and quantidade != 0 "
            end
        end

        if !params[:cod_empresa].blank?
            consulta += " and cod_empresa = "+params[:cod_empresa] + " "
        end

        if !params[:term].blank?
            consulta += " and cod_produto in (select cod_produto from produto where 
            cod_produto::varchar = REPLACE(TRIM('"+ params[:term] +"%'), \'%\', \'\') OR nome ILIKE '"+ params[:term] +"%')";
            # consulta += " and cod_produto in (select cod_produto 
            #                                     from produto where upper(nome) ilike upper('"+ params[:term] +"%')) "
        end
        # puts "Consulta ======>>>>>  "+ consulta
        @empresa_produtos = Empresaproduto.where(consulta).page(params[:page])

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
