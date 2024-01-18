class CollaboratorsBackoffice::VendasController < CollaboratorsBackofficeController

    before_action :set_venda, only: [:destroy]

    def index
      # @sale = Venda.where("cod_empresa = ? an tipo = 'V'", current_collaborator.cod_empresa).order(:cod_venda)
      # @sale = Venda.new(params_venda)
      # @codigo = Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
    end
  
    def consulta_estoque
      # puts "CONSULTA ESTOQUE #{params} "x
      @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade).joins(:empresaprodutos).where("cod_produto = ? and cod_empresa = ?", params[:id_produto], current_collaborator.cod_empresa ).order(:nmcor, :cod_cor);
      respond_to do |format|
        format.json { render json: @cores }
      end
    end

    def new
      @sale = Venda.new
      @sale.cod_vendaempresa = Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
      @sale.cod_empresa = current_collaborator.cod_empresa
      @sale.itensvenda.build
      #@sale.contas.build
    end
  
    def create
      @sale = Venda.new(params_venda)

      @sale.cod_vendaempresa = Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
      @sale.cod_empresa = current_collaborator.cod_empresa
      @sale.cod_funcionario = current_collaborator.cod_funcionario
      @sale.tipo = 'V'
      @sale.cancelada = false
      @sale.datanf = nil

      # Crie uma nova coleção contendo apenas os itens desejados
      itens_a_manter = @sale.itensvenda.reject { |item_venda| item_venda.cod_produto.nil? }

      # Atribua a nova coleção à associação
      @sale.itensvenda = itens_a_manter

      # @sale.contas.each do |conta|
      #   conta.cod_empresa = @sale.cod_empresa;
      #   conta.ativo = true;
      #   conta.quitada = false;
      #   conta.cod_tppagamento = 1; # 1 é parcela de venda
      # end

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

    private 
    
    def set_venda
      @sale = Venda.find(params[:id])
    end

    def params_venda
      params.require(:venda).permit(
        :tipo, :cod_empresa, :cancelada, :datanf, :datavenda, :numeronf, :valortotal, :cod_frete, :cod_funcionario, 
        :cod_empresa_transferida, :cod_vendaempresa, :acrescimo, :desconto, :aceita, :cod_pessoa,
        itensvenda_attributes: [:cod_produto, :quantidade, :valorunitario, :cod_cor, :cod_empresa, :_destroy],
        contas_attributes: [ :cod_venda, :dtvencimento, :numeroparcela, :valorparcela, :_destroy, :cod_empresa, 
                                :ativo, :quitada, :cod_tppagamento] )
  
      end
  end
  