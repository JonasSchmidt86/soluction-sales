class CollaboratorsBackoffice::DocumentosFiscaisController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_venda, only: [:emitir, :preview, :show, :cancelar, :danfe]
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

  # GET .../documentos_fiscais/preview — CONFERE os dados fiscais que irao na
  # NF-e (itens, CFOP/CST/impostos do perfil, destinatario, totais) SEM emitir.
  # Serve para o usuario validar que a tributacao esta no lugar antes de enviar.
  def preview
    operacao = OperacaoFiscal.find_by(nome: "Venda")
    config   = FiscalConfig.find_by(cod_empresa: @venda.cod_empresa)

    if operacao.nil? || config.nil?
      redirect_to edit_collaborators_backoffice_venda_path(@venda),
                  alert: "Configuração fiscal ausente (operação 'Venda' ou FiscalConfig)."
      return
    end

    @documento_neutro = Fiscal::DocumentoFiscalBuilder.new(
      @venda, operacao: operacao, config: config, modelo: 55
    ).montar

    @pendencias = pendencias_fiscais(@venda)
  rescue Fiscal::DocumentoFiscalBuilder::DadoFiscalAusente => e
    redirect_to edit_collaborators_backoffice_venda_path(@venda),
                alert: "Não foi possível montar a prévia: #{e.message}"
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

  # Lista de problemas que impediriam/arriscariam a emissao, para destacar
  # na previa (NCM/origem/perfil do produto, destinatario sem UF, etc.).
  def pendencias_fiscais(venda)
    problemas = []

    venda.itensvenda.reject(&:cancelado?).each do |item|
      prod = item.produto
      nome = prod&.nome || "produto #{item.cod_produto}"
      problemas << "#{nome}: sem NCM" if prod&.ncm.blank?
      problemas << "#{nome}: sem perfil tributário" if prod&.perfil_tributario.nil?
      problemas << "#{nome}: sem origem" if prod&.origem.blank?
    end

    cliente = venda.pessoa
    problemas << "Destinatário sem UF/endereço" if cliente&.uf.blank?
    problemas << "Destinatário sem CPF/CNPJ" if cliente&.cpf_cnpj.blank?

    problemas
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
