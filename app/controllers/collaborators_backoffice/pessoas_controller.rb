class CollaboratorsBackoffice::PessoasController < CollaboratorsBackofficeController

    before_action :set_pessoa, only: [:show, :edit, :update, :destroy]
  
    def index
      
      puts params[:tipo]
      if !params[:tipo].blank?
        consulta = " tipo = '" + params[:tipo] + "'"
      end
      unless params[:name].blank?
        consulta += "and nome ilike '" + params[:name] + "%'";
      end

      per_page = params[:per_page].present? ? params[:per_page].to_i : 30
      if params[:per_page].present? && params[:per_page].to_i === 0
        @pessoas = Pessoa.order(datacadastro: :desc).where(consulta);
      else
        @pessoas = Pessoa.order(datacadastro: :desc).where(consulta).page(params[:page]).per(per_page);
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
          redirect_to @pessoa, notice: 'Pessoa criada com sucesso.'
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
                                      :registradoscpc, :email
      )
    end
  end