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
      @sale = Venda.new #(params_venda)
      # puts "NEW SALE ----------"
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

      # puts @sale.itensvenda.size

      @sale.contas.each do |conta|
        conta.cod_empresa = @sale.cod_empresa;
        conta.ativo = true;
        conta.quitada = false;
        conta.cod_tppagamento = 1;
      end

      if @sale.save
          redirect_to collaborators_backoffice_report_sales_path, notice: "Venda Cadastrado com sucesso!"
      else 
        puts @sale
          render :index
      end
    end

    def edit
      puts "-----------EDIT ------------"
      puts params
      @sale = Venda.find_by(cod_venda: params[:id])
      # if !@sale.blank?
      #   redirect_to collaborators_backoffice_venda_path(@sale), notice: "Venda"
      # end
    end

    def destroy
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
        contas_attributes: [ :cod_venda, :dtvencimento, :numeroparcela, :valorparcela, :_destroy] )
  
      end
      
      # # parcelas
      # cod_contaspagrec bigint NOT NULL,
      # cod_empresa bigint NOT NULL,
      # ativo boolean,
      # cod_compra bigint,
      # cod_frete bigint,
      # cod_venda bigint,
      # dtvencimento date,
      # numeroparcela integer,
      # quitada boolean,
      # valorparcela numeric(18,2) DEFAULT 0.00,
      # cod_tppagamento bigint,
  
  
      # # itens
      # cod_item bigint NOT NULL,
      # cod_empresa bigint NOT NULL,
      # cod_produto bigint,
      # cod_venda bigint,
      # numeronf bigint,
      # quantidade numeric(18,2) DEFAULT 0.00,
      # valorunitario numeric(18,2) DEFAULT 0.00,
      # cod_cor bigint,
      # cancelado boolean NOT NULL DEFAULT false,
      # aceita boolean DEFAULT false,
      # valororiginal numeric(18,2) DEFAULT 0.00,
  
      # # Sale
      # tipo character varying(1) COLLATE pg_catalog."default" NOT NULL,
      # cod_empresa bigint NOT NULL,
      # cancelada boolean,
      # datanf timestamp without time zone,
      # datavenda timestamp without time zone,
      # numeronf bigint,
      # valortotal numeric(18,2) DEFAULT 0.00,
      # cod_frete bigint,
      # cod_funcionario bigint NOT NULL,
      # cod_empresa_transferida bigint,
      # cod_vendaempresa bigint,
      # cod_venda bigint NOT NULL DEFAULT nextval('venda_cod_venda_seq'::regclass),
      # cod_pessoa bigint,
      # acrescimo numeric(18,3) DEFAULT 0.000,
      # desconto numeric(18,3) DEFAULT 0.000,
      # aceita boolean DEFAULT false,
      
  
  end
  