class CollaboratorsBackoffice::Report::RepSalesController < CollaboratorsBackofficeController
    
    def index
        unless params[:cod_pessoa].blank?
            consulta = " cod_pessoa = " + params[:cod_pessoa]
        else
            consulta = "cod_empresa = ? "
            if !params[:term].blank?
                consulta += " and cod_pessoa in (select cod_pessoa from pessoa where upper(nome) like upper('%"+ params[:term] +"%')) "
            end

            if !params[:dataInicial].blank? && !params[:dataFinal].blank?
                consulta += " and date(datavenda) between to_date('" + params[:dataInicial] +"', 'DD/MM/YYYY') and to_date('" + params[:dataFinal] + "', 'DD/MM/YYYY') "
            else
                consulta += " and date(datavenda) between to_date('" + Time.now.strftime("%d/%m/%Y") +"', 'DD/MM/YYYY') and to_date('" + Date.today.end_of_month.strftime("%d/%m/%Y") + "', 'DD/MM/YYYY') "
            end
        end

        # tipo T é transferencia 
        consulta += " and tipo <> 'T' "
        @sales = Venda.where(consulta, current_collaborator.cod_empresa )
                                    .order(datavenda: :desc).page(params[:page])
    end
end
