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
        # Parameters: {"utf8"=>"✓", "status_bill"=>"Abertos", "nrVenda"=>"13191", "cliente"=>"", "dataInicial"=>"01/03/2023", "dataFinal"=>"31/03/2023"}
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
            @launch = Lancamentoscaixa.new
            @launch.datapagto = DateTime.now
            @launch.funcionario = current_collaborator.funcionario
            @launch.valor = params[:lancamentoscaixa][:valor] # verificar como fazer
            @launch.empresa = Empresa.find(current_collaborator.cod_empresa)

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
                
                }  ), notice: "Conta Baixada com sucesso!"
            else
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => the_params[:tipo_conta] ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
                :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal]
                }  ), notice: "ERRO AO SALVAR CONTA!"
            end
        end
        
        # redirect_to collaborators_backoffice_contas_pag_rec_index_path , notice: "CREATE"
    end

    def destroy
    end

    def update
        puts "UPDATE"
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
