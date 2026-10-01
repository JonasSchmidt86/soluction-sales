class CollaboratorsBackoffice::DocumentosFiscaisController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_venda, only: [:emitir, :show, :cancelar, :danfe]
  before_action :set_documento, only: [:show, :cancelar, :danfe]

  # POST /collaborators_backoffice/vendas/:venda_id/documentos_fiscais/emitir
  # Emite (ou reemite) a NF-e modelo 55 da venda. O EmissorFiscal reaproveita
  # o mesmo documento quando a venda ja tem uma tentativa rejeitada/erro.
  def emitir
    documento = Fiscal::EmissorFiscal.new(
      @venda,
      modelo: 55,
      cod_funcionario: current_collaborator.cod_funcionario
    ).emitir

    if documento.autorizada?
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  notice: "NF-e autorizada. Chave: #{documento.chave_acesso}"
    else
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "NF-e #{documento.status}: #{documento.mensagem_sefaz}"
    end
  rescue Fiscal::EmissorFiscal::JaAutorizada => e
    redirect_to edit_collaborators_backoffice_venda_path(@venda), alert: e.message
  rescue Fiscal::EmissorFiscal::SemConfig, Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to edit_collaborators_backoffice_venda_path(@venda), alert: e.message
  rescue => e
    Rails.logger.error("[DocumentosFiscais#emitir] venda #{@venda.cod_venda}: #{e.class} - #{e.message}")
    redirect_to edit_collaborators_backoffice_venda_path(@venda),
                alert: "Falha ao emitir NF-e: #{e.message}"
  end

  # GET .../documentos_fiscais/:id  — detalhes do documento (status, mensagem).
  def show
  end

  # GET .../documentos_fiscais/:id/danfe — baixa o PDF do DANFE (base64).
  def danfe
    if @documento.danfe_base64.blank?
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "DANFE indisponível para este documento."
      return
    end

    send_data Base64.decode64(@documento.danfe_base64),
              filename: "danfe-#{@documento.chave_acesso.presence || @documento.cod_documento_fiscal}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  # POST .../documentos_fiscais/:id/cancelar — cancela NF autorizada.
  def cancelar
    unless @documento.autorizada?
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "Só é possível cancelar uma NF autorizada."
      return
    end

    justificativa = params[:justificativa].to_s.strip
    if justificativa.length < 15
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "A justificativa de cancelamento precisa ter ao menos 15 caracteres."
      return
    end

    result = FiscalService.new(@documento.empresa.fiscal_config)
                          .cancelar(@documento.chave_acesso, justificativa)
    @documento.aplicar_resultado!(result)

    redirect_to edit_collaborators_backoffice_venda_path(@venda),
                notice: "NF-e cancelada."
  rescue NotImplementedError
    redirect_to edit_collaborators_backoffice_venda_path(@venda),
                alert: "Cancelamento ainda não implementado para este provedor."
  rescue => e
    Rails.logger.error("[DocumentosFiscais#cancelar] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to edit_collaborators_backoffice_venda_path(@venda),
                alert: "Falha ao cancelar NF-e: #{e.message}"
  end

  private

  def set_venda
    @venda = Venda.find(params[:venda_id])
  end

  def set_documento
    @documento = DocumentoFiscal
                 .where(cod_venda: @venda.cod_venda)
                 .find(params[:id])
  end

  # Gate do modulo fiscal: por ora so o super_admin ve/usa a emissao, e so
  # quando logado numa empresa que tem o modulo fiscal ativo (evita emitir
  # pela empresa errada). Depois: trocar por empresa_tem_modulo_fiscal? apenas.
  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
