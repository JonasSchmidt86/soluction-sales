class CollaboratorsBackoffice::BuscasController < CollaboratorsBackofficeController
    
    def buscar_pessoas
      query = params[:query].downcase
      result = Pessoa.select(:nome, :cod_pessoa, :cpf_cnpj)
                    .where('LOWER(nome) ILIKE :query OR cpf_cnpj ILIKE :query', query: "%#{query}%")
                    .order(:nome)
                    .limit(10)
      render json: result
    end

    def buscar_produtos
      entidade = params[:entidade]
      query = params[:query]
      puts params[:query].downcase
      
      if entidade.present?
        entity_class = entidade.constantize
        result = entity_class.select(:nome, :cod_produto, "CONCAT(cod_produto, ' - ', nome) as produto ")
          .where('cod_produto::varchar = REPLACE(TRIM(:query), \'%\', \'\') OR nome ILIKE :query ', query: "%#{query}%")
          .order(:nome)
          .limit(30)
      else
        # Para pedido de compra sem entidade
        result = Produto.select(:nome, :cod_produto)
          .where('cod_produto::varchar ILIKE :query OR LOWER(nome) ILIKE :query', query: "%#{query.downcase}%")
          .order(:nome)
          .limit(30)
      end
      
      render json: result
    end

    def consulta_estoque
      puts "CONSULTA CORES #{params} "
      @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade)
                   .joins(:empresaprodutos)
                   .where("cod_produto = ? and cod_empresa = ?", params[:id_produto], current_collaborator.cod_empresa)
                   .order(quantidade: :desc, nmcor: :asc, cod_cor: :asc)
      respond_to do |format|
        format.json { render json: @cores }
      end
    end
    
    def check_cpf_cnpj
      cpf_cnpj = params[:cpf_cnpj].gsub(/\D/, '')  # Remove todos os caracteres não numéricos
      pessoa = Pessoa.find_by(cpf_cnpj: cpf_cnpj)
      
      # Verifica se uma pessoa foi encontrada
      if pessoa
        puts pessoa
        render json: pessoa
      else
        render json: { status: 'not_found' }
      end

    end

  end
