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

                    if params[:nf_pedido].present?
                        nf_pedido = "%#{params[:nf_pedido].strip.upcase}%"
                        scope = scope.where(
                            "UPPER(compra.numeronf) LIKE :q OR UPPER(compra.nr_pedido) LIKE :q",
                            q: nf_pedido
                        )
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
                    scope = scope.where(datacompra: data_inicial.beginning_of_day..data_final.end_of_day)

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

        carregar_documentos_fiscais
    end

    private

    # Pre-carrega o ULTIMO DocumentoFiscal por compra (devolucao), para a lista
    # decidir entre mostrar "Devolver NF" ou o status da devolucao ja feita, sem
    # disparar uma query por linha (N+1). So roda para super_admin com modulo
    # fiscal (quem ve o botao de devolucao). Mesmo padrao do relatorio de vendas.
    def carregar_documentos_fiscais
        @docs_por_compra = {}
        return unless empresa_tem_modulo_fiscal? && access_control.super_admin?

        cod_compras = @buys.map(&:cod_compra).compact
        return if cod_compras.empty?

        DocumentoFiscal.where(cod_compra: cod_compras)
                       .order(cod_documento_fiscal: :desc)
                       .each { |d| @docs_por_compra[d.cod_compra] ||= d }
    end
end