class CollaboratorsBackoffice::ContasPagRecController < CollaboratorsBackofficeController


    before_action :set_bill, only: [:edit, :update, :destroy]
    # before_action :params_bill, only: [:update]

    def index

        @array =  ['Abertos', 'Liquidados', 'Todos']

        # pega o primeiro dia e o ultimo dia do mes
        puts Time.now.strftime("%d/%m/%Y")
        puts Date.today.end_of_month.strftime("%d/%m/%Y")
        consulta = "";      
        if !params[:nrVenda].blank?
            consulta += " cod_venda in (select cod_venda from Venda where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and cod_vendaempresa = " + params[:nrVenda] + ") "
        else
            
            if !params[:tipo_conta].nil? && params[:tipo_conta]
                consulta += "  (cod_compra is not null or cod_frete is not null) and cod_venda is null "
            else
                consulta += "  cod_venda is not null and cod_frete is null "
            end
            
            if !params[:dataInicial].blank? && !params[:dataFinal].blank?
                consulta += " and date(dtvencimento) between to_date('" + params[:dataInicial] +"', 'DD/MM/YYYY') and to_date('" + params[:dataFinal] + "', 'DD/MM/YYYY') "
            else
                consulta += " and date(dtvencimento) between to_date('" + Time.now.strftime("%d/%m/%Y") +"', 'DD/MM/YYYY') and to_date('" + Date.today.end_of_month.strftime("%d/%m/%Y") + "', 'DD/MM/YYYY') "
            end

            if !params[:cliente].blank?
                consulta += "and cod_venda in (select cod_venda from venda where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and cod_pessoa in (select cod_pessoa from pessoa where upper(nome) like upper('"+ params[:cliente] +"%')))"
            end
            
            if params[:status_bill] == "Abertos"
                consulta += "  and contaspagrec.quitada = false "
            elsif params[:status_bill] == "Liquidados"
                consulta += "  and contaspagrec.quitada = true "
            end

        end

        consulta += " and cod_empresa = ? ";

        @bills = Contaspagrec.where(consulta, current_collaborator.empresa.cod_empresa)
                    .order(dtvencimento: :asc).includes(:lancamentos).page(params[:page])

    end
    
    def edit
        puts "Dentro do EDIT  "
        redirect_to collaborators_backoffice_contas_pag_rec_index_path , notice: "Conta já esta Baixada"
    end

    def destroy
    end

    def update

        if !@bill.nil?
            @bill.quitada = true
            partion((@bill.valorparcela - @bill.valorPago), nil)

            # if @bill.save
            #     redirect_to collaborators_backoffice_contas_pag_rec_index_path , notice: "Conta Baixada com sucesso!"
            # else
            #     :index
            #     # redirect_to collaborators_backoffice_contas_pag_rec_index_path , notice: "Erro ao Baixada Conta!"
            # end
        end 
        puts "Dentro do UPDATE  "
        
    end

private 

    def params_bill
        params.require(:contaspagrec).permit(:quitada, :ativo)
        # params.require(:lancamento).permit(:quitada, lancamentos_attributes: [:cod_lancamentocaixa, :_destroy])
    end

    def set_bill 
        @bill = Contaspagrec.find(params[:id])
        @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa).limit(1)
        # puts "bill _------------- >>>>>>>>>>  nm Pessoa: " +  @bill.nmPessoa.to_s
    end

    def partion(param_valor, historic)
        @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa.cod_empresa).first   
        
        if @caixa.nil?
            flash[:alert] = "Caixa não esta aberto!"
            :index
        else
            @launch = Lancamentoscaixa.new
            @launch.datapagto = DateTime.now
            @launch.funcionario = current_collaborator.funcionario
            @launch.valor = param_valor # verificar como fazer
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
            @launch.contaspagrec = @bill

            @launch.caixa = @caixa

            if @launch.save
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => params[:tipo_conta] ,:status_bill => params[:status_bill], :nrVenda => params[:nrVenda], 
                :cliente => params[:cliente], :dataInicial => params[:dataInicial], :dataFinal => params[:dataFinal]
                
                }) , notice: "Conta Baixada com sucesso!"
            else
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => params[:tipo_conta] ,:status_bill => params[:status_bill], :nrVenda => params[:nrVenda], 
                :cliente => params[:cliente], :dataInicial => params[:dataInicial], :dataFinal => params[:dataFinal]
                
                }) , notice: "ERRO AO SALVAR CONTA!"
            end
        end
    end

end
