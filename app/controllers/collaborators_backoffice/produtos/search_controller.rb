class CollaboratorsBackoffice::Produtos::SearchController < CollaboratorsBackofficeController

    # def produtos
    #     @produtos = Produto.where("upper(nome) like ? and ativo = true ", 
    #                 "#{params[:term].upcase}%").order('cod_produto').page(params[:page])
                    
    # end

    def produtos
        query = params[:term]
        @produtos = Produto.where('cod_produto::varchar = REPLACE(TRIM(:query), \'%\', \'\') OR nome ILIKE :query ', query: "%#{query}%")
          .order(:cod_produto).page(params[:page])
  
      end

end
