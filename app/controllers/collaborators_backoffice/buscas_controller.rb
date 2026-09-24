class CollaboratorsBackoffice::BuscasController < CollaboratorsBackofficeController
    
    def buscar_pessoas
      query = params[:query].downcase

      # Em transferencia (tipo 'T') a busca lista EMPRESAS cadastradas, nao
      # pessoas: uma mesma pessoa pode ter mais de uma empresa, entao o que
      # importa e escolher a empresa de destino. O front envia
      # somente_empresas=true nesse caso.
      if ActiveModel::Type::Boolean.new.cast(params[:somente_empresas])
        result = Empresa
                   .joins(:pessoa)
                   .where.not(cod_pessoa: nil)
                   .where('LOWER(empresa.nome) ILIKE :q OR LOWER(pessoa.nome) ILIKE :q OR pessoa.cpf_cnpj ILIKE :q',
                          q: "#{query}%")
                   .order('empresa.nome')
                   .limit(10)
                   .map do |e|
                     {
                       nome: e.nome,               # nome da empresa (exibido)
                       cod_empresa: e.cod_empresa, # destino da transferencia
                       cod_pessoa: e.cod_pessoa,
                       cpf_cnpj: e.pessoa&.cpf_cnpj
                     }
                   end
        return render json: result
      end

      result = Pessoa.select(:nome, :cod_pessoa, :cpf_cnpj)
                    .where('LOWER(nome) ILIKE :query OR cpf_cnpj ILIKE :query', query: "#{query}%")
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
      # puts "CONSULTA CORES #{params} "
      @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade)
                   .joins(:empresaprodutos)
                   .where("cod_produto = ? and cod_empresa = ?", params[:id_produto], current_collaborator.cod_empresa)
                   .order(quantidade: :desc, nmcor: :asc, cod_cor: :asc)
      if @cores.blank?
        @cores = Core.where(cod_cor:  1);
      end

      respond_to do |format|
        format.json { render json: @cores }
      end
    end
    
    # Retorna as cores de um produto que estão com estoque negativo
    # na empresa do colaborador logado (tabela empresaproduto).
    # Usado para avisar, no form de importacao de XML, que o produto
    # possui cor(es) "vendida(s)" (estoque negativo).
    def cores_negativas
      cores = Core.select(:cod_cor, :nmcor, "empresaproduto.quantidade AS quantidade")
                  .joins(:empresaprodutos)
                  .where("empresaproduto.cod_produto = ? AND empresaproduto.cod_empresa = ? AND empresaproduto.quantidade < 0",
                         params[:cod_produto], current_collaborator.cod_empresa)
                  .order(:nmcor, :cod_cor)

      render json: cores.map { |c| { cod_cor: c.cod_cor, nmcor: c.nmcor, quantidade: c.quantidade } }
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
