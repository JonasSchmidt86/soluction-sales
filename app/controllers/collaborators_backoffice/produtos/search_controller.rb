class CollaboratorsBackoffice::Produtos::SearchController < CollaboratorsBackofficeController

    def produtos
        @produtos = Produto.where("upper(nome) like ? and ativo = true ", 
                    "#{params[:term].upcase}%").order('cod_produto').page(params[:page])
    end

end
