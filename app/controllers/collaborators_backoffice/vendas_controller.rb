class CollaboratorsBackoffice::VendasController < CollaboratorsBackofficeController

    before_action :set_venda, only: [:destroy]

    def index
      # @sale = Venda.where("cod_empresa = ? an tipo = 'V'", current_collaborator.cod_empresa).order(:cod_venda)
      # @sale = Venda.new(params_venda)
      # @codigo = Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
    end
  
    def consulta_estoque
      # puts "CONSULTA ESTOQUE #{params} "x
      @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade)
                   .joins(:empresaprodutos)
                   .where("cod_produto = ? and cod_empresa = ?", params[:id_produto], current_collaborator.cod_empresa)
                   .order(quantidade: :desc, nmcor: :asc, cod_cor: :asc)
      respond_to do |format|
        format.json { render json: @cores }
      end
    end

    def new
      puts " ---------- new --------- #{params}"

      @sale = Venda.new
      @sale.cod_empresa = current_collaborator.cod_empresa
      # @sale.itensvenda.build
      1.times { @sale.itensvenda.build }
      # @sale.contas.build
    end
  
    def create
      puts " -------- create ---------- #{params}"
      @sale = Venda.new(params_venda)

      if !params[:venda][:cod_pessoa].blank?
        @pessoa = Pessoa.find_by(cod_pessoa: params[:venda][:cod_pessoa])
      end
      if @pessoa.nil?
        @pessoa = Pessoa.new
        @pessoa.cpf_cnpj = params[:venda][:pessoa_attributes][:cpf_cnpj] if params[:venda][:pessoa_attributes][:cpf_cnpj].present?
        @pessoa.rg_ie = params[:venda][:pessoa_attributes][:cpf_cnpj] if params[:venda][:pessoa_attributes][:rg_ie].present?
      end

      @pessoa.email = params[:venda][:pessoa_attributes][:nome] if params[:venda][:pessoa_attributes][:nome].present?
      @pessoa.telefone = params[:venda][:pessoa_attributes][:telefone] if params[:venda][:pessoa_attributes][:telefone].present?
      @pessoa.celular = params[:venda][:pessoa_attributes][:celular] if params[:venda][:pessoa_attributes][:celular].present?
      @pessoa.cep = params[:venda][:pessoa_attributes][:cep] if params[:venda][:pessoa_attributes][:cep].present?
      @pessoa.cod_cidade = params[:venda][:pessoa_attributes][:cod_cidade] if params[:venda][:pessoa_attributes][:cod_cidade].present?
      @pessoa.complemento = params[:venda][:pessoa_attributes][:complemento] if params[:venda][:pessoa_attributes][:complemento].present?
      @pessoa.endereco = params[:venda][:pessoa_attributes][:endereco] if params[:venda][:pessoa_attributes][:endereco].present?
      @pessoa.bairro = params[:venda][:pessoa_attributes][:bairro] if params[:venda][:pessoa_attributes][:bairro].present?
      @pessoa.numero = params[:venda][:pessoa_attributes][:numero] if params[:venda][:pessoa_attributes][:numero].present?
      @pessoa.email = params[:venda][:pessoa_attributes][:email] if params[:venda][:pessoa_attributes][:email].present?
      
      @sale.pessoa = @pessoa

      @sale.cod_vendaempresa = Venda.select(:cod_vendaempresa).where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
      @sale.cod_empresa = current_collaborator.cod_empresa
      @sale.cod_funcionario = current_collaborator.cod_funcionario
      @sale.tipo = 'V'
      @sale.cancelada = false
      @sale.datanf = nil

      # Crie uma nova coleção contendo apenas os itens desejados
      itens_a_manter = @sale.itensvenda.reject { |item_venda| item_venda.cod_produto.nil? }
      conta_a_manter = @sale.contas.reject { |conta| (conta.numeroparcela.blank? || conta.valorparcela.blank? ||  conta.dtvencimento.blank?) }

      # Atribua a nova coleção à associação
      @sale.itensvenda = itens_a_manter
      @sale.contas = conta_a_manter

      puts "ANTES DE SALVAR"

      if @sale.save
          redirect_to collaborators_backoffice_report_sales_path, notice: "Venda Cadastrado com sucesso!"
      else 
        puts @sale
        render :index
      end
    end

    def edit
      puts params
      @sale = Venda.find_by(cod_venda: params[:id])
    end

    def destroy

      @sale.contas.each do |conta|
        if !conta.lancamentos.blank?
          # ver como vai cancelar a venda o que fazer com os lançamentos
          redirect_to collaborators_backoffice_report_sales_path, notice: "Venda possui lançamentos de caixa!"
          return
        end
      end

      if @sale.destroy
        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda Excluida com sucesso!"
      else
        redirect_to collaborators_backoffice_report_sales_path, notice: "Não foi possivel excluir venda!"
      end

      rescue => e
        redirect_to collaborators_backoffice_report_sales_path, notice: "Erro ao excluir a venda!"
    end

    def check_cpf_cnpj_venda
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

    private 
    
    def set_venda
      @sale = Venda.find(params[:id])
    end

    def params_venda
      params.require(:venda).permit(
        :tipo, :cod_empresa, :cancelada, :datanf, :datavenda, :numeronf, :valortotal, :cod_frete, :cod_funcionario, 
        :cod_empresa_transferida, :cod_vendaempresa, :acrescimo, :desconto, :aceita, :cod_pessoa,
        itensvenda_attributes: [:cod_produto, :quantidade, :valorunitario, :cod_cor, :cod_empresa, :_destroy],
        contas_attributes: [  :cod_venda, :dtvencimento, :numeroparcela, :valorparcela, 
                              :_destroy, :cod_empresa, :ativo, :quitada, :cod_tppagamento ],
        pessoa_attributes: [  :tipo, :nome, :telefone, :celular, :cep, 
                              :cod_cidade, :complemento, :endereco, :bairro, :numero, :email ]
      )
    end
    
  end
  