class CollaboratorsBackoffice::LancamentoscaixasController < CollaboratorsBackofficeController
    
    before_action :set_lembrete, only: [:edit, :update, :destroy]
    before_action :get_empresas, only: [:new, :edit, :update,]

    def index
    end

    def edit
    end

    def new
        @lancamento = Lancamentoscaixa.new
    end

    def create
        the_params = params[:lancamentoscaixa]
        @launch = Lancamentoscaixa.new

        @bill =  Contaspagrec.find(params[:lancamentoscaixa][:contaspagrec])

        @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa.cod_empresa).first   
        
        if @caixa.nil?
            redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
            { :tipo_conta => (the_params[:tipo_conta].length == 0) ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
            :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal]
            }  ), notice: "Caixa não esta aberto!"
        else
            @launch = Lancamentoscaixa.new;
            @launch.datapagto = DateTime.now;
            @launch.funcionario = current_collaborator.funcionario;

            valor_com_ponto_e_virgula = params[:lancamentoscaixa][:valor]

            # Substituir vírgula por ponto e remover ponto de milhar
            valor_com_ponto = valor_com_ponto_e_virgula.gsub(".", "").sub(",", ".")

            # Convertendo para float
            valor_float = valor_com_ponto.to_f
            @launch.valor = valor_float

            @launch.empresa = Empresa.find(current_collaborator.cod_empresa);
            @launch.cancelada = false;

            # se for venda entrada e se for compra ou frete saida
            if !@bill.venda.nil?
                @launch.tipo = 'E'
                @launch.cod_tphitorico = 1 # parcela de venda
            elsif !@bill.compra.nil?
                @launch.tipo = 'S'
                @launch.cod_tphitorico = 2 # parcela de compra
            elsif !@bill.frete.nil?
                @launch.tipo = 'S'
                @launch.cod_tphitorico = 6 # pagamento de frete
            end

            if !params[:lancamentoscaixa][:contaspagrec].nil? || !params[:lancamentoscaixa][:contaspagrec].blank?
                @bill.quitada = params[:lancamentoscaixa][:quitada]
            end

            @launch.contaspagrec = @bill

            @launch.caixa = @caixa

            @launch.dataabertura = @caixa.dataabertura
            
            @launch.datamodificacao = DateTime.now

            if @launch.save
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => the_params[:tipo_conta] ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
                :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal]
                
                }  ), notice: "Parcial de conta baixada."
            else
                messsage = "Erro ao salvar a conta!"

                if @launch.errors[:valor]
                    message = @launch.errors[:valor].first.to_s.gsub(/[\[\]]/, '');
                end
                    redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                    { :tipo_conta => the_params[:tipo_conta] ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
                    :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal]
                    }  ), notice: message;
            end
        end
    end

    def destroy
    end

    def update
        redirect_to collaborators_backoffice_contas_pag_rec_index_path , notice: "UPDATE"
    end

    private 

    def params_launchs
        params.require(:lancamentoscaixa).permit(:valor, :dataabertura, :quitada, contaspagrec_attributes:[:contaspagrec] )
    end

    def set_lembrete
    end

    def get_empresas
    end 
end
