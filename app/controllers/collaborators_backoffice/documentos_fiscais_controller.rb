class CollaboratorsBackoffice::DocumentosFiscaisController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_venda, only: [:emitir, :espelho, :previsualizar, :show, :cancelar, :danfe, :xml, :reconciliar, :evento_arquivo]
  before_action :set_documento, only: [:show, :cancelar, :danfe, :xml, :reconciliar, :evento_arquivo]

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
    redirect_to collaborators_backoffice_report_sales_path, alert: e.message
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to collaborators_backoffice_report_sales_path, alert: e.message
  rescue => e
    Rails.logger.error("[DocumentosFiscais#emitir] venda #{@venda.cod_venda}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_report_sales_path,
                alert: "Falha ao emitir NF-e: #{e.message}"
  end

  # GET .../documentos_fiscais/espelho — gera um PDF "espelho" da NF-e com todos
  # os dados (emitente, destinatario, itens com tributacao, totais), SEM valor
  # fiscal e sem precisar de autorizacao da SEFAZ. Serve para conferencia/impressao.
  def espelho
    operacao = OperacaoFiscal.find_by(nome: "Venda")
    config   = FiscalConfig.find_by(cod_empresa: @venda.cod_empresa)

    if operacao.nil? || config.nil?
      redirect_to collaborators_backoffice_report_sales_path,
                  alert: "Configuração fiscal ausente (operação 'Venda' ou FiscalConfig)."
      return
    end

    doc = Fiscal::DocumentoFiscalBuilder.new(@venda, operacao: operacao, config: config, modelo: 55).montar

    html = ApplicationController.render(
      template: "collaborators_backoffice/documentos_fiscais/espelho_pdf",
      layout: false,
      assigns: { venda: @venda, empresa: @venda.empresa, documento_neutro: doc }
    )
    pdf = WickedPdf.new.pdf_from_string(html, orientation: "Portrait", page_size: "A4",
                                        margin: { top: 8, bottom: 8, left: 8, right: 8 })
    send_data pdf, filename: "espelho-nfe-venda-#{@venda.cod_venda}.pdf",
              type: "application/pdf", disposition: "inline"
  rescue => e
    Rails.logger.error("[DocumentosFiscais#espelho] venda #{@venda.cod_venda}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_report_sales_path,
                alert: "Não foi possível gerar o espelho: #{e.message}"
  end

  # GET .../documentos_fiscais/previsualizar — DANFE de PRE-VISUALIZACAO gerado
  # pelo provedor (sem transmitir a SEFAZ, sem consumir numeracao). Mais fiel
  # ao DANFE real que o espelho local em HTML.
  def previsualizar
    preview = Fiscal::EmissorFiscal.new(
      @venda, modelo: 55,
      cod_funcionario: current_collaborator.cod_funcionario
    ).pre_visualizar(tipo_arquivo: 1)

    if preview.sucesso?
      send_data preview.conteudo,
                filename: "previsualizacao-nfe-venda-#{@venda.cod_venda}.pdf",
                type: "application/pdf", disposition: "inline"
    else
      redirect_to collaborators_backoffice_report_sales_path,
                  alert: "Não foi possível pré-visualizar: #{preview.erro}"
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to collaborators_backoffice_report_sales_path, alert: e.message
  rescue => e
    Rails.logger.error("[DocumentosFiscais#previsualizar] venda #{@venda.cod_venda}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_report_sales_path,
                alert: "Falha ao pré-visualizar: #{e.message}"
  end

  # POST .../documentos_fiscais/:id/reconciliar — consulta a SEFAZ
  # (ConsultarNotaFiscal) e atualiza o status/arquivos deste documento.
  # Util quando ficou "enviada"/"erro" por queda de rede mas pode ter autorizado.
  def reconciliar
    consulta = @documento.reconciliar_status!
    destino = collaborators_backoffice_report_sales_path

    if consulta.nil?
      redirect_to destino, alert: "Não foi possível consultar (sem chave/identificador ou config fiscal)."
    elsif !consulta.encontrada?
      redirect_to destino, alert: "Documento não localizado na SEFAZ: #{consulta.erro || consulta.mensagem}"
    else
      redirect_to destino,
                  notice: "Status atualizado: #{@documento.status}#{" — #{consulta.mensagem}" if consulta.mensagem.present?}"
    end
  rescue => e
    Rails.logger.error("[DocumentosFiscais#reconciliar] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_report_sales_path, alert: "Falha ao consultar: #{e.message}"
  end

  # GET .../documentos_fiscais/:id/evento_arquivo?evento_id=&tipo=
  # Baixa o arquivo de um EVENTO (CC-e/cancelamento) via provedor
  # (ObterArquivoEvento), usando a chave do documento + o protocolo do evento.
  # tipo: "pdf" (default, PDF da CC-e) ou "xml" (XML do evento).
  def evento_arquivo
    evento = @documento.eventos.find_by(cod_documento_fiscal_evento: params[:evento_id])
    if evento.nil? || evento.protocolo.blank? || @documento.chave_acesso.blank?
      redirect_to collaborators_backoffice_report_sales_path,
                  alert: "Evento sem protocolo ou documento sem chave."
      return
    end

    tipo_arquivo = params[:tipo].to_s == "xml" ? 1 : 2
    config = FiscalConfig.find_by(cod_empresa: @documento.cod_empresa)
    if config.nil? || !config.ativo?
      redirect_to collaborators_backoffice_report_sales_path, alert: "Empresa sem configuração fiscal ativa."
      return
    end

    arquivo = FiscalService.new(config).obter_arquivo_evento(
      chave: @documento.chave_acesso, protocolo: evento.protocolo, tipo_arquivo: tipo_arquivo
    )

    if arquivo.sucesso?
      ext = tipo_arquivo == 1 ? "xml" : "pdf"
      mime = tipo_arquivo == 1 ? "application/xml" : "application/pdf"
      disp = tipo_arquivo == 1 ? "attachment" : "inline"
      send_data arquivo.conteudo,
                filename: "evento-#{evento.tipo}-#{evento.protocolo}.#{ext}",
                type: mime, disposition: disp
    else
      redirect_to collaborators_backoffice_report_sales_path,
                  alert: "Arquivo do evento indisponível: #{arquivo.erro}"
    end
  rescue => e
    Rails.logger.error("[DocumentosFiscais#evento_arquivo] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_report_sales_path, alert: "Falha ao obter o evento: #{e.message}"
  end

  # GET .../documentos_fiscais/:id  — detalhes do documento (status, mensagem).
  def show
  end

  # GET .../documentos_fiscais/:id/danfe — baixa o PDF do DANFE.
  # Usa o danfe_base64 salvo; se ausente, BUSCA no provedor pela chave
  # (ObterArquivoNotaFiscal). Assim o DANFE fica sempre disponível.
  def danfe
    if @documento.danfe_base64.present?
      send_data Base64.decode64(@documento.danfe_base64),
                filename: "danfe-#{nome_arquivo(@documento)}.pdf",
                type: "application/pdf", disposition: "inline"
      return
    end

    arquivo = buscar_arquivo_no_provedor(@documento, file_type: 2)
    if arquivo&.sucesso?
      send_data arquivo.conteudo, filename: "danfe-#{nome_arquivo(@documento)}.pdf",
                type: "application/pdf", disposition: "inline"
    else
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "DANFE indisponível: #{arquivo&.erro || 'documento sem chave ou não encontrado'}."
    end
  end

  # GET .../documentos_fiscais/:id/xml — baixa o XML da NF. Usa o salvo; se
  # ausente, busca no provedor pela chave (ObterArquivoNotaFiscal).
  def xml
    if @documento.xml_base64.present?
      enviar_xml(Base64.decode64(@documento.xml_base64), @documento)
      return
    end

    arquivo = buscar_arquivo_no_provedor(@documento, file_type: 1)
    if arquivo&.sucesso?
      enviar_xml(arquivo.conteudo, @documento)
    else
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "XML indisponível: #{arquivo&.erro || 'documento sem chave ou não encontrado'}."
    end
  end

  # POST .../documentos_fiscais/:id/cancelar — cancela NF autorizada.
  #
  # Grava o evento de cancelamento (quem/quando/motivo) via DocumentoFiscal#cancelar!.
  # Param `escopo`:
  #   "nf"    (default) — cancela apenas a NF-e; a venda continua ativa.
  #   "ambos"           — cancela a NF-e e, se homologada, cancela a VENDA
  #                       (estorno de estoque e contas, via fluxo de destroy).
  def cancelar
    justificativa = params[:justificativa].to_s.strip
    escopo = params[:escopo].presence || "nf"
    destino = collaborators_backoffice_report_sales_path

    result = @documento.cancelar!(
      justificativa:   justificativa,
      cod_funcionario: current_collaborator.cod_funcionario
    )

    unless result.sucesso?
      redirect_to destino, alert: "NF-e não cancelada: #{result.mensagem}"
      return
    end

    if escopo == "ambos"
      cancelar_venda_apos_nf!(@venda)
      redirect_to destino, notice: "NF-e e venda canceladas. Estoque e contas estornados."
    else
      redirect_to destino, notice: "NF-e cancelada. Chave: #{@documento.chave_acesso}"
    end
  rescue ArgumentError => e
    redirect_to destino, alert: e.message
  rescue NotImplementedError
    redirect_to destino, alert: "Cancelamento ainda não implementado para este provedor."
  rescue => e
    Rails.logger.error("[DocumentosFiscais#cancelar] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to destino, alert: "Falha ao cancelar NF-e: #{e.message}"
  end

  private

  # Cancela a VENDA apos a NF ja ter sido cancelada na SEFAZ. Espelha o fluxo
  # de VendasController#destroy (estorno de contas com lancamento + marcacao de
  # cancelada, que dispara o trigger de devolucao de estoque). NAO exclui a
  # venda (mantem para auditoria/historico fiscal).
  def cancelar_venda_apos_nf!(venda)
    return if venda.cancelada?

    venda.contas.each do |conta|
      if conta.lancamentos.present?
        caixa = Caixa.where(cod_empresa: current_collaborator.empresa.cod_empresa, datafechamento: nil).first
        raise "Caixa fechado: não é possível estornar as contas da venda." if caixa.nil?
        EstornarContaService.new(conta, current_collaborator, caixa).call
      end
      conta.update!(ativo: false)
    end

    venda.update_columns(cancelada: true, cod_funcionario: current_collaborator.cod_funcionario)
    venda.itensvenda.where(cancelado: [false, nil]).update_all(cancelado: true)
  end

  # Busca o arquivo (XML/PDF) do documento no provedor pela chave de acesso.
  # Retorna FiscalArquivo ou nil (sem chave/config). Venda = saida (tipo 1).
  def buscar_arquivo_no_provedor(documento, file_type:)
    return nil if documento.chave_acesso.blank?
    config = FiscalConfig.find_by(cod_empresa: documento.cod_empresa)
    return nil if config.nil? || !config.ativo?

    FiscalService.new(config).obter_arquivo(
      chave: documento.chave_acesso, file_type: file_type, tipo_documento: 1
    )
  rescue => e
    Rails.logger.error("[DocumentosFiscais#buscar_arquivo] doc #{documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    nil
  end

  def enviar_xml(conteudo, documento)
    send_data conteudo, filename: "nfe-#{nome_arquivo(documento)}.xml",
              type: "application/xml", disposition: "attachment"
  end

  def nome_arquivo(documento)
    documento.chave_acesso.presence || documento.cod_documento_fiscal
  end

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
