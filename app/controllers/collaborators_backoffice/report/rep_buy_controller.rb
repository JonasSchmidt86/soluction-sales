class CollaboratorsBackoffice::Report::RepBuyController < CollaboratorsBackofficeController
    
    def index
        per_page = params[:per_page].to_i.zero? ? 30 : params[:per_page].to_i
        base_scope = Compra.includes(:frete, :itenscompra, :contas, :pessoa, :empresa, :collaborator, :xml_file)

        compras = if params[:cod_pessoa].present?
                    base_scope.where(cod_pessoa: params[:cod_pessoa])
                    else
                    scope = base_scope.where(cod_empresa: current_collaborator.cod_empresa)

                    if params[:term].present?
                        term = "%#{params[:term].upcase}%"
                        scope = scope.joins(:pessoa).where("UPPER(pessoa.nome) LIKE ?", term)
                    end

                    data_inicial, data_final = if params[:dataInicial].present? && params[:dataFinal].present?
                                                [
                                                    Date.strptime(params[:dataInicial], '%d/%m/%Y'),
                                                    Date.strptime(params[:dataFinal], '%d/%m/%Y')
                                                ]
                                                else
                                                [
                                                    Time.zone.today.beginning_of_month,
                                                    Time.zone.today.end_of_month
                                                ]
                                                end
                    scope = scope.where(datacompra: data_inicial..data_final)

                    if params[:cod_funcionario].present?
                        scope = scope.where(cod_funcionario: params[:cod_funcionario])
                    end

                    scope
                    end

        @buys = if params[:per_page].present? && params[:per_page].to_i.zero?
                    compras.order(datacompra: :desc)
                else
                    compras.order(datacompra: :desc).page(params[:page]).per(per_page)
                end
    end


end