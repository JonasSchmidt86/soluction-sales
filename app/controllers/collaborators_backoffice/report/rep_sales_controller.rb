class CollaboratorsBackoffice::Report::RepSalesController < CollaboratorsBackofficeController
    
    def index
        per_page = params[:per_page].to_i.zero? ? 30 : params[:per_page].to_i

        vendas = Venda.includes(:empresa, :funcionario, :pessoa, itensvenda: :produto, contas: :lancamentos)

        vendas = vendas.where(cod_empresa: current_collaborator.cod_empresa)
        
        # 🔎 busca direta
        if params[:codigo_venda].present?
            @sales = vendas.where(cod_venda: params[:codigo_venda].to_i)
                        .order(datavenda: :desc)
            return
        end

        # 🔥 tipo (transferência)
        if params[:transferencia] == '1'
            vendas = vendas.where(tipo: 'T')
        else
            vendas = vendas.where.not(tipo: 'T')
        end

        # 🔥 cancelada
        if params[:cancelada].present? && params[:cancelada].to_i == 0
            vendas = vendas.where(cancelada: false)
        end

        # 🔥 pessoa
        if params[:cod_pessoa].present?
            vendas = vendas.where(cod_pessoa: params[:cod_pessoa])
        end

        # 🔥 busca por nome
        if params[:term].present?
            term = "%#{params[:term].upcase}%"
            vendas = vendas.joins(:pessoa).where("UPPER(pessoa.nome) LIKE ?", term)
        end

        # 🔥 datas
        if params[:dataInicial].present? && params[:dataFinal].present?
            data_inicial = Date.strptime(params[:dataInicial], '%d/%m/%Y')
            data_final   = Date.strptime(params[:dataFinal], '%d/%m/%Y')
        elsif params[:dataInicial].present?
            data_inicial = Date.strptime(params[:dataInicial], '%d/%m/%Y')
            data_final   = data_inicial.end_of_month
        else
            data_inicial = Time.zone.today.beginning_of_month
            data_final   = Time.zone.today.end_of_month
        end

        vendas = vendas.where(datavenda: data_inicial.beginning_of_day..data_final.end_of_day)

        # 🔥 funcionário
        if params[:cod_funcionario].present?
            vendas = vendas.where(cod_funcionario: params[:cod_funcionario])
        end

        # 🔥 paginação
        @sales =
            if params[:per_page].present? && params[:per_page].to_i.zero?
            vendas.order(datavenda: :desc)
            else
            vendas.order(datavenda: :desc).page(params[:page]).per(per_page)
            end
        end


    def hist_client

        puts "rep sales historico cliente "
        # unless params[:cod_pessoa].blank?
            consulta = " cod_pessoa = " + params[:id]
        # else
        #     consulta = "cod_empresa = ? "
        #     if !params[:term].blank?
        #         consulta += " and cod_pessoa in (select cod_pessoa from pessoa where upper(nome) like upper('%"+ params[:term] +"%')) "
        #     end

        #     if !params[:dataInicial].blank? && !params[:dataFinal].blank?
        #         consulta += " and date(datavenda) between to_date('" + params[:dataInicial] +"', 'DD/MM/YYYY') and to_date('" + params[:dataFinal] + "', 'DD/MM/YYYY') "
        #     else
        #         consulta += " and date(datavenda) between to_date('" + Time.now.strftime("%d/%m/%Y") +"', 'DD/MM/YYYY') and to_date('" + Date.today.end_of_month.strftime("%d/%m/%Y") + "', 'DD/MM/YYYY') "
        #     end
        # end
        @sales = Venda.where(consulta, current_collaborator.cod_empresa )
                                    .order(datavenda: :desc).page(params[:page])
    end
end
