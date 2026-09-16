class CollaboratorsBackoffice::PessoasController < CollaboratorsBackofficeController

    before_action :set_pessoa, only: [:show, :edit, :update, :destroy]
  
    def index

      scope = Pessoa.order(datacadastro: :desc)

      scope = scope.where(tipo: params[:tipo]) if params[:tipo].present?

      # Busca unica por nome OU CPF/CNPJ. O termo digitado pode vir com mascara
      # (pontos, barra, tracos); como o cpf_cnpj e gravado apenas com digitos,
      # comparamos tambem a versao "so digitos" do termo.
      if params[:name].present?
        termo = params[:name].strip
        somente_digitos = termo.gsub(/\D/, '')

        if somente_digitos.present?
          scope = scope.where(
            "nome ILIKE :nome OR cpf_cnpj ILIKE :doc",
            nome: "%#{termo}%",
            doc: "%#{somente_digitos}%"
          )
        else
          scope = scope.where("nome ILIKE :nome", nome: "%#{termo}%")
        end
      end

      if params[:per_page].present? && params[:per_page].to_i === 0
        @pessoas = scope
      else
        per_page = params[:per_page].present? ? params[:per_page].to_i : 30
        @pessoas = scope.page(params[:page]).per(per_page)
      end

    end
  
    def show
    end
  
    def new
      @pessoa = Pessoa.new
    end
  
    def create
      @pessoa = Pessoa.new(pessoa_params)
      pessoaExistente = Pessoa.find_by(cpf_cnpj: @pessoa.cpf_cnpj);
      
      if request.xhr? # Verifica se é uma requisição AJAX
        if !pessoaExistente.blank?
          render json: pessoaExistente
        elsif @pessoa.save
          render json: @pessoa
        else
          render json: @pessoa.errors, status: :unprocessable_entity
        end
      else # Requisição normal do Rails
        if !pessoaExistente.blank?
          redirect_to edit_collaborators_backoffice_pessoa_path(pessoaExistente.cod_pessoa), notice: 'Pessoa já existe cadastrada!'
        elsif @pessoa.save
          redirect_to collaborators_backoffice_pessoas_path , notice: 'Pessoa criada com sucesso.'
        else
          render :new
        end
      end
    end
  
    def edit
    end
  
    def update
      if @pessoa.update(pessoa_params)
        redirect_to collaborators_backoffice_pessoas_path, notice: 'Pessoa atualizada com sucesso.'
      else
        render :edit
      end
    end
  
    def destroy
      @pessoa.destroy
      redirect_to pessoas_url, notice: 'Pessoa excluída com sucesso.'
    end

    def check_cpf_cnpj

      cpf_cnpj = params[:cpf_cnpj].gsub(/\D/, '')  # Remove todos os caracteres não numéricos
      pessoa = Pessoa.select(:cod_pessoa).find_by(cpf_cnpj: cpf_cnpj)
      
      if pessoa
        render json: { redirect_url: edit_collaborators_backoffice_pessoa_path(pessoa) }
      else
        render json: { status: 'not_found' };
      end

    end

    # Busca os dados de uma empresa pelo CNPJ (BrasilAPI) e ja resolve a cidade
    # interna (cod_cidade) pelo codigo IBGE. Usado via AJAX no cadastro de PJ.
    def buscar_cnpj
      cnpj = params[:cnpj].to_s.gsub(/\D/, '')

      if cnpj.length != 14
        render json: { status: 'invalid', message: 'CNPJ inválido.' }, status: :unprocessable_entity and return
      end

      result = BrasilapiService.get_company_by_cnpj(cnpj)

      if result[:error].present?
        status, message = case result[:error]
                          when :not_found    then [:not_found, 'CNPJ não encontrado.']
                          when :rate_limited then [:too_many_requests, 'Muitas consultas em sequência. Aguarde alguns segundos e tente novamente.']
                          else                    [:service_unavailable, 'Serviço de consulta de CNPJ indisponível no momento.']
                          end
        render json: { status: 'error', reason: result[:error], message: message }, status: status and return
      end

      company = result[:data]

      render json: {
        status: 'ok',
        nome: company[:razao_social],
        apelido: company[:nome_fantasia],
        cep: company[:cep],
        endereco: company[:endereco],
        numero: company[:numero],
        complemento: company[:complemento],
        bairro: company[:bairro],
        telefone: company[:telefone],
        email: company[:email],
        data_abertura: company[:data_abertura],
        cod_cidade: BrasilapiService.get_id_cidade(company)
      }
    end
  
    private
  
    def set_pessoa
      @pessoa = Pessoa.find(params[:id])
    end
    
    def pessoa_params
      params[:pessoa][:cpf_cnpj].gsub!(/\D/, '') if params[:pessoa][:cpf_cnpj].present?
      params[:pessoa][:civil].present? ? params[:pessoa][:civil] : nil
      params.require(:pessoa).permit( :tipo, :cpf_cnpj, :apelido, :bairro , :celular, :cep, :complemento, 
                                      :datacadastro, :endereco, :nome, :numero, :rg_ie, :telefone, :civil, :cpfconj, 
                                      :dtnascimento, :dtnascimentoconj, :emprego, :nomeconj, :rgconjuge, :salario, 
                                      :pessoacontato, :telefonecontato, :cod_cidade, :credito, :nrcadpro, :dtconsulta, 
                                      :registradoscpc, :email, :origem_id
      )
    end
  end