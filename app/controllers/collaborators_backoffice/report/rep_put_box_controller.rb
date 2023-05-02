class CollaboratorsBackoffice::Report::RepPutBoxController < CollaboratorsBackofficeController
    
    before_action :set_launch, only: [:destroy]

    def index
        # pega o primeiro dia e o ultimo dia do mes
        puts Time.now.strftime("%d/%m/%Y")
        puts Date.today.end_of_month.strftime("%d/%m/%Y")

        consulta = " lancamentoscaixa.cod_empresa = ? 
                     and lancamentoscaixa.caixa_id is not null
                     and lancamentoscaixa.cod_bancoconta is null ";
        
        if (params[:dataInicial].blank? && params[:dataFinal].blank?)
            consulta += " and date(lancamentoscaixa.datapagto) between TO_DATE('"+ Time.now.strftime("%d/%m/%Y") +"', 'DD/MM/YYYY') and TO_DATE('"+ Date.today.end_of_month.strftime("%d/%m/%Y") +"', 'DD/MM/YYYY') ";
        else
            consulta += " and date(lancamentoscaixa.datapagto) between TO_DATE('"+ params[:dataInicial] +"', 'DD/MM/YYYY') and TO_DATE('"+ params[:dataFinal] +"', 'DD/MM/YYYY') ";

        end
        
        unless params[:cod_historico].blank?
            consulta += " and lancamentoscaixa.cod_tphitorico = " + params[:cod_historico];
        end
        
        unless params[:cod_operacao].blank?
            if params[:cod_operacao].eql? "2"
                consulta += " and lancamentoscaixa.tipo = 'E' "
            elsif params[:cod_operacao].eql? "3"
                consulta += " and lancamentoscaixa.tipo = 'S' "
            elsif params[:cod_operacao].eql? "4"
                consulta += " and lancamentoscaixa.cancelada = true "
            end
        end

        unless (params[:cliente].blank?)
            consulta += "
            and case when lancamentoscaixa.cod_contaspagrec is not null
                    then
                        case when (select n.cod_venda from Contaspagrec as n where n.cod_contaspagrec = lancamentoscaixa.cod_contaspagrec) is not null 
                                then lancamentoscaixa.cod_contaspagrec in (select n.cod_contaspagrec from ContasPagRec as n where cod_venda in (select cod_venda from Venda where cod_pessoa in (select p.cod_pessoa from Pessoa as p where upper(p.nome) like upper('"+params[:cliente]+"%') )))     
                        when (select n.cod_compra from Contaspagrec as n where n.cod_contaspagrec = lancamentoscaixa.cod_contaspagrec) is not null         
                                then lancamentoscaixa.cod_contaspagrec in (select n.cod_contaspagrec from ContasPagRec as n where n.cod_compra in (select cod_compra from Compra where cod_pessoa in (select p.cod_pessoa from Pessoa as p where upper(p.nome) like upper('"+params[:cliente]+"%') )))     
                        when (select n.cod_frete from Contaspagrec as n where n.cod_contaspagrec = lancamentoscaixa.cod_contaspagrec) is not null         
                                then lancamentoscaixa.cod_contaspagrec in (select n.cod_contaspagrec from ContasPagRec as n where n.cod_Frete in (select cod_frete from Frete where cod_pessoa in (select p.cod_pessoa from Pessoa as p where upper(p.nome) like upper('"+params[:cliente]+"%') )))     
                    end  
                when descricao is not null        
                    then upper(lancamentoscaixa.descricao) like upper('"+params[:cliente]+"%') 
                else 
                    false 
                end "
        end

        @lauches = Lancamentoscaixa.where(consulta, current_collaborator.cod_empresa )
                                .order( datapagto: :desc ).page(params[:page]);
    end

    def destroy
        @bill = @launch.contaspagrec
        @bill.quitada = false
        if @bill.save
            if @launch.destroy
                redirect_to collaborators_backoffice_report_put_box_index_path, notice: "Lancamento excluido com sucesso! E conta Ativada com sucesso!"
            else
                redirect_to collaborators_backoffice_report_put_box_index_path, notice: "Erro ao excluir Lancamento!"
            end
        else
            redirect_to collaborators_backoffice_report_put_box_index_path, notice: "Não foi possivel reativar a conta!"
        end

    end

    private

    def set_launch
        @launch = Lancamentoscaixa.find(params[:id])
    end

end
