class CollaboratorsBackoffice::BuscasController < CollaboratorsBackofficeController
    
    def buscar_pessoas
      entidade = params[:entidade]
      query = params[:query].downcase
      puts params[:query].downcase
      entity_class = entidade.constantize
      # Lógica para buscar a entidade no banco de dados (substitua 'Entidade' pelo nome real da sua entidade/modelo)
      result = entity_class.select(:nome, :cod_pessoa).where(' LOWER(nome) ILIKE ? ', "%#{query}%").order(:nome).limit(10); #.pluck(:nome);
  
      render json: result
    end

    def buscar_produtos

      entidade = params[:entidade]
      query = params[:query]
      puts params[:query].downcase
      entity_class = entidade.constantize
      # Lógica para buscar a entidade no banco de dados (substitua 'Entidade' pelo nome real da sua entidade/modelo)
      result = entity_class.select(:nome, :cod_produto, "CONCAT(cod_produto, ' - ', nome) as produto ")
        .where('cod_produto::varchar = REPLACE(TRIM(:query), \'%\', \'\') OR nome ILIKE :query ', query: "%#{query}%")
        .order(:nome)
        .limit(30)
      render json: result

    end

  end
