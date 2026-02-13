class CollaboratorsBackoffice::LancamentoscaixasController < CollaboratorsBackofficeController
    
    before_action :set_lembrete, only: [:edit, :update, :destroy]
    before_action :get_empresas, only: [:new, :edit, :update,]

    def index
        #@lancamentos = Lancamentoscaixa.where("cod_empresa = ? and date(datapagto) = date( ? ) ", current_collaborator.empresa.cod_empresa,  (Date.today - 4)).page(params[:page]);
    end

    def edit
    end

    def new
        @lancamento = Lancamentoscaixa.new
    end

    def create
        the_params = params[:lancamentoscaixa]
        origem = params[:origem]
        @launch = Lancamentoscaixa.new

        valor_com_ponto_e_virgula = the_params[:valor]

        # Substituir vírgula por ponto e remover ponto de milhar
        valor_com_ponto = valor_com_ponto_e_virgula.gsub(".", "").sub(",", ".")

        # Convertendo para float
        valor_float = valor_com_ponto.to_f
        
        if the_params[:contaspagrec].present?
            @bill =  Contaspagrec.find(params[:lancamentoscaixa][:contaspagrec])
        end
        
        @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa.cod_empresa).first
         
        if the_params[:cod_bancoconta].present? && the_params[:cod_bancoconta].to_i > 0
            @launch.cod_bancoconta = the_params[:cod_bancoconta].to_i
        end
        # verificar @caixa se existe se ele não existir e não tiver conta bancária selecionada retornar erro de caixa não aberto
        if @caixa.nil? && the_params[:cod_bancoconta].blank?
            puts the_params.inspect
            if origem == "payment_modal"
                redirect_to pagamentos_collaborators_backoffice_lancamentosdiversos_path(), alert: "Caixa não esta aberto! Ou conta bancária não selecionada!"
            elsif origem == "bills_partial_modal"
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                    { :tipo_conta => the_params[:tipo_conta] ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
                    :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal],
                    :cod_bancoconta => params[:cod_bancoconta]
                    }  ), alert: "Caixa não esta aberto! Ou conta bancária não selecionada!"
            else
                redirect_to collaborators_backoffice_report_put_box_index_path, alert: "Caixa não esta aberto! Ou conta bancária não selecionada!"
            end
            
            return
        end

        if @bill.nil? || @bill == ""
            
            if the_params[:lancamento_id].present? && origem == "payment_modal"
                puts "Lançamento ID presente: #{the_params[:lancamento_id]}"
                @lancamentosdiverso = Lancamentosdiverso.find(the_params[:lancamento_id])

                if @lancamentosdiverso.nil?
                    redirect_to colaboradores_backoffice_lancamentosdiversos_pagamentos_path(), alert: "Lançamento não encontrado!"
                    return
                end

                @launch = Lancamentoscaixa.new;
                @launch.datapagto = DateTime.now;
                @launch.funcionario = current_collaborator.funcionario;
                @launch.descricao = @lancamentosdiverso.descricao;
                @launch.cod_bancoconta = the_params[:cod_bancoconta].present? ? the_params[:cod_bancoconta].to_i : nil  
                unless the_params[:cod_bancoconta].present? && the_params[:cod_bancoconta].to_i > 0
                    @launch.caixa = @caixa;
                    @launch.dataabertura = @caixa.dataabertura;
                end
                
                @launch.valor = valor_float
                
                @launch.empresa = Empresa.find(current_collaborator.cod_empresa);
                @launch.cancelada = false;
                @launch.historico = @lancamentosdiverso.historico
                @launch.cod_lancamentodiverso = @lancamentosdiverso.id
                @launch.tipo = @lancamentosdiverso.entrada ? 'E' : 'S'
                if @launch.save!
                    redirect_to pagamentos_collaborators_backoffice_lancamentosdiversos_path(
                        Rack::Utils.parse_nested_query(params[:return_params])
                    ), notice: "Lançamento gravado com Sucesso!"
                else
                    redirect_to pagamentos_collaborators_backoffice_lancamentosdiversos_path, notice: "Erro ao gravar lançamento!"
                end
                return
            end

            @launch = Lancamentoscaixa.new;
            @launch.datapagto = DateTime.now;
            @launch.funcionario = current_collaborator.funcionario;
            @launch.descricao = the_params[:descricao];

            @launch.caixa = @caixa.blank? ? nil : @caixa;

            if the_params[:cod_bancoconta].present? && the_params[:cod_bancoconta].to_i > 0
                @launch.cod_bancoconta = the_params[:cod_bancoconta].to_i
            end
            
            @launch.valor = valor_float

            @launch.empresa = Empresa.find(current_collaborator.cod_empresa);
            @launch.cancelada = false;
            @launch.historico = Tiposhistoricoscaixa.find(params[:cod_historico].to_i);

            if the_params[:tipo] == "E"
                @launch.tipo = 'E'
                @launch.dataabertura = @caixa.dataabertura;
            else
                @launch.tipo = 'S'
                if the_params[:cod_bancoconta].present? && the_params[:cod_bancoconta].to_i > 0
                    @launch.caixa = nil;
                else
                    @launch.dataabertura = @caixa.dataabertura;
                end
            end

            if @launch.save!
                redirect_to collaborators_backoffice_report_put_box_index_path, notice: "Lançamento gravado com Sucesso!"
            else
                redirect_to collaborators_backoffice_report_put_box_index_path, notice: "Erro ao gravar lançamento!"
            end
            return

        else          
        
            # if the_params[:cod_bancoconta].present? && the_params[:cod_bancoconta].to_i > 0
            #     @launch.cod_bancoconta = the_params[:cod_bancoconta].to_i
            # end

            
            @launch = Lancamentoscaixa.new;
            @launch.datapagto = DateTime.now;
            @launch.funcionario = current_collaborator.funcionario;

            @launch.valor = valor_float

            @launch.empresa = Empresa.find(current_collaborator.cod_empresa);
            @launch.cancelada = false;

# aqui mudar bill
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
# fim bill
            # puts "---------------------------"
            # puts the_params[:cod_bancoconta]
            # puts "---------------------------"
            
            if the_params[:cod_bancoconta].present? && the_params[:cod_bancoconta].to_i > 0
                @launch.cod_bancoconta = the_params[:cod_bancoconta].to_i
            else
                @launch.caixa = @caixa
                @launch.dataabertura = @caixa.dataabertura
            end
            
            @launch.datamodificacao = DateTime.now

            if @bill.quitada
                msg = "Total da conta baixada."
            else
                msg = "Parcial de conta baixada." 
            end

            if @launch.save
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => the_params[:tipo_conta] ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
                :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal],
                :cod_bancoconta => params[:cod_bancoconta]
                }  ), notice: msg
            else
                messsage = ""

                if @launch.errors[:valor]
                    message =+ @launch.errors[:valor].first.to_s.gsub(/[\[\]]/, '');
                else 
                    if @launch.errors
                        message = @launch.errors
                    end
                end
                    redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                    { :tipo_conta => the_params[:tipo_conta] ,:status_bill => the_params[:status_bill], :nrVenda => the_params[:nrVenda], 
                    :cliente => the_params[:cliente], :dataInicial => the_params[:dataInicial], :dataFinal => the_params[:dataFinal],
                    :cod_bancoconta => the_params[:cod_bancoconta]
                    }  ), notice: "Erro ao salvar a conta!" + message;
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
        params.require(:lancamentoscaixa).permit(:valor, :dataabertura, :quitada, :cod_tphitorico, :cod_bancoconta, contaspagrec_attributes:[:contaspagrec] )
    end

    def set_lembrete
    end

    def get_empresas
    end 
end
