class CollaboratorsBackoffice::ContasPagRecController < CollaboratorsBackofficeController


    before_action :set_bill, only: [:edit, :update, :destroy]
    # before_action :params_bill, only: [:update]

    def index
        @array =  ['Abertos', 'Liquidados', 'Todos']
        puts params
        {"controller"=>"collaborators_backoffice/contas_pag_rec", "action"=>"index", "format"=>"18185"}

        if !params[:nrVenda].blank?
            @bills = Contaspagrec.includes(:lancamentos).where(consulta_index, current_collaborator.empresa.cod_empresa)
                        .order(dtvencimento: :asc, cod_contaspagrec: :desc );
        elsif params[:cod_compra].present? 
            puts "-----------------------cod Compra---"
            @bills = Contaspagrec.includes(:lancamentos).where("cod_compra = ? and cod_empresa = ?", params[:cod_compra], current_collaborator.empresa.cod_empresa)
                        .order(dtvencimento: :asc, cod_contaspagrec: :desc );
        else

            per_page = params[:per_page].present? ? params[:per_page].to_i : 30

            if params[:per_page].present? && params[:per_page].to_i === 0
                @bills = Contaspagrec.includes(:lancamentos).where(consulta_index, current_collaborator.empresa.cod_empresa)
                        .order(dtvencimento: :asc, cod_contaspagrec: :desc );
            else
                @bills = Contaspagrec.includes(:lancamentos).where(consulta_index, current_collaborator.empresa.cod_empresa)
                        .order(dtvencimento: :asc, cod_contaspagrec: :desc ).page(params[:page]).per(per_page);
            end
        end
    end
    
    def edit
        redirect_to collaborators_backoffice_contas_pag_rec_index_path , notice: "Conta já esta Baixada"
    end

    def destroy
    end

    def update
        if !@bill.nil?
            @bill.quitada = true
            partion((@bill.valorparcela - @bill.valorPago), nil)
        end 
    end

private 

    def consulta_index
        consulta = "";      
        if !params[:nrVenda].blank?
            if params[:tipo_conta].present? && !params[:tipo_conta].nil? && params[:tipo_conta] == 'true'
                consulta += " cod_compra in (select cod_compra from Compra where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and numeronf = '" + params[:nrVenda] + "') "
            else
                consulta += " cod_venda in (select cod_venda from Venda where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and cod_vendaempresa = " + params[:nrVenda] + ") "
            end            
        else 
            if params[:tipo_conta].present? && !params[:tipo_conta].nil? && params[:tipo_conta] == 'true'
                consulta += "  cod_venda is null "
            else
                consulta += "  cod_venda is not null and cod_frete is null "
                consulta += "  and cod_venda not in (select cod_venda from venda where tipo = 'T' and cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + ") "
            end
            
            if !params[:dataInicial].blank? && !params[:dataFinal].blank?
                consulta += " and date(dtvencimento) between to_date('" + params[:dataInicial] +"', 'DD/MM/YYYY') and to_date('" + params[:dataFinal] + "', 'DD/MM/YYYY') "
            else
                consulta += " and date(dtvencimento) between to_date('" + Time.now.strftime("01/%m/%Y") +"', 'DD/MM/YYYY') and to_date('" + Date.today.end_of_month.strftime("%d/%m/%Y") + "', 'DD/MM/YYYY') "
            end

            if !params[:cliente].blank?
                unless params[:tipo_conta].present? && !params[:tipo_conta].nil? && params[:tipo_conta] == 'true'
                    consulta += "and cod_venda in (select cod_venda from venda where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and cod_pessoa in (select cod_pessoa from pessoa where upper(trim(nome)) like upper(trim('"+ params[:cliente] +"%'))))"
                else
                    consulta += "and (cod_compra in (select cod_compra from Compra where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and cod_pessoa in (select cod_pessoa from pessoa where upper(trim(nome)) like upper(trim('"+ params[:cliente] +"%')))) or (cod_frete in (select cod_frete from frete where cod_empresa = " + current_collaborator.empresa.cod_empresa.to_s + " and cod_pessoa in (select cod_pessoa from pessoa where upper(trim(nome)) like upper(trim('"+ params[:cliente] +"%'))))))"
                end
            end
            
            if params[:status_bill] == "Abertos"
                consulta += "  and contaspagrec.quitada = false "
            elsif params[:status_bill] == "Liquidados"
                consulta += "  and contaspagrec.quitada = true "
            end

        end
        # puts consulta;
        return consulta += " and cod_empresa = ? and ativo = true ";
    end

    def params_bill
        params.require(:contaspagrec).permit(:quitada, :ativo)
        # params.require(:lancamento).permit(:quitada, lancamentos_attributes: [:cod_lancamentocaixa, :_destroy])
    end

    def set_bill 
        @bill = Contaspagrec.find(params[:id])
        @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa).limit(1)
    end

    def partion(param_valor, historic)
        @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa.cod_empresa).first   
        
        if @caixa.nil? && params[:cod_bancoconta].blank?
            redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => params[:tipo_conta] ,:status_bill => params[:status_bill], :nrVenda => params[:nrVenda], 
                :cliente => params[:cliente], :dataInicial => params[:dataInicial], :dataFinal => params[:dataFinal]
                }) , notice: "Abra o caixa para baixar a conta!!"
        else

            @launch = Lancamentoscaixa.new
            @launch.datapagto = DateTime.now
            @launch.funcionario = current_collaborator.funcionario
            @launch.valor = param_valor # verificar como fazer
            @launch.empresa = Empresa.find(current_collaborator.cod_empresa)
            @launch.cancelada = false
            @launch.cod_bancoconta = params[:cod_bancoconta]
            puts "--------------------------"
            puts "Banco: #{params[:cod_bancoconta]}"
            puts "--------------------------"
            unless params[:cod_bancoconta]
                @launch.caixa = @caixa    
            end

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

            @launch.dataabertura = @caixa.dataabertura
            
            @launch.datamodificacao = DateTime.now

            @bill.lancamentos << @launch

            puts "ANTES SAVE";

            if @bill.save
                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => params[:tipo_conta] ,:status_bill => params[:status_bill], :nrVenda => params[:nrVenda], 
                :cliente => params[:cliente], :dataInicial => params[:dataInicial], :dataFinal => params[:dataFinal]
                
                }) , notice: "Conta Baixada com sucesso!"
            else
                if @bill.errors
                    message = @bill.errors
                    puts @bill.errors.first.to_s
                end

                redirect_to collaborators_backoffice_contas_pag_rec_index_path(@bill, 
                { :tipo_conta => params[:tipo_conta] ,:status_bill => params[:status_bill], :nrVenda => params[:nrVenda], 
                :cliente => params[:cliente], :dataInicial => params[:dataInicial], :dataFinal => params[:dataFinal]
                
                }) , notice: message
            end
        end
    end

end


# select cod_empresa, cod_produto, cod_cor, quantidade, function_estoquereal(cod_empresa,cod_produto,cod_cor ) as real
#   from empresaproduto 
#  where cod_empresa = 2 
#    and cod_produto >= 5000 and cod_produto < 10000
#    and quantidade != function_estoquereal(cod_empresa,cod_produto,cod_cor )
 
#  order by cod_produto asc
 
