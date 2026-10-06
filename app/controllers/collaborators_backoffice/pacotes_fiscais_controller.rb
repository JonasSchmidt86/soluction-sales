class CollaboratorsBackoffice::PacotesFiscaisController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_config
  before_action :set_pacote, only: [:baixar, :enviar_contador, :destroy]

  # Histórico de pacotes gerados.
  def index
    @pacotes = PacoteFiscal.da_empresa(current_collaborator.cod_empresa)
                           .recentes.page(params[:page])
  end

  # Gera o pacote do período CHAMANDO O PROVEDOR UMA VEZ e o SALVA (Active
  # Storage). Depois, baixar/reenviar usam o arquivo salvo (sem novo provedor).
  def gerar
    unless @config&.persisted? && @config.ativo?
      return redirect_to pacotes_path, alert: "Configuração fiscal ausente ou inativa."
    end
    dt_inicio = params[:dt_inicio].presence
    dt_fim    = params[:dt_fim].presence
    if dt_inicio.blank? || dt_fim.blank?
      return redirect_to pacotes_path, alert: "Informe o período (início e fim)."
    end

    tipo_arquivo = params[:tipo_arquivo].presence&.to_i || 1
    tipo_nota    = params[:tipo_nota].presence&.to_i || 1
    incluir_cce  = ActiveModel::Type::Boolean.new.cast(params[:incluir_cce])

    pacote_api = FiscalService.new(@config).obter_arquivos_periodo(
      dt_inicio: dt_inicio, dt_fim: dt_fim,
      tipo_arquivo: tipo_arquivo, tipo_nota: tipo_nota, incluir_cce: incluir_cce
    )
    unless pacote_api.sucesso?
      return redirect_to pacotes_path, alert: "Não foi possível gerar o pacote: #{pacote_api.erro}"
    end

    conteudo = pacote_api.conteudo
    # Prefixo pelo tipo de nota (saida/entrada) para o contador identificar fácil.
    prefixo = { 1 => "saida", 2 => "entrada", 3 => "saida-entrada" }[tipo_nota] || "fiscal"
    nome = "#{prefixo}-#{dt_inicio}_a_#{dt_fim}.#{pacote_api.extensao}"
    pacote = PacoteFiscal.new(
      cod_empresa:    current_collaborator.cod_empresa,
      periodo_inicio: dt_inicio, periodo_fim: dt_fim,
      tipo_arquivo:   tipo_arquivo, tipo_nota: tipo_nota, incluir_cce: incluir_cce,
      nome_arquivo:   nome, mime: pacote_api.mime,
      quantidade:     (pacote_api.quantidade rescue nil),
      tamanho_bytes:  conteudo&.bytesize,
      gerado_em:      Time.current,
      cod_funcionario: current_collaborator.cod_funcionario
    )
    # Organiza o arquivo em storage/XML/<empresa>/<AAAA-MM>/<nome>. A key custom
    # vira o caminho real (StorageService). Mes = inicio do periodo. Sufixo curto
    # evita colisao se gerar o mesmo tipo/periodo mais de uma vez.
    empresa_slug = current_collaborator.empresa&.nome.to_s.parameterize(separator: "_").presence || "empresa_#{current_collaborator.cod_empresa}"
    mes_pasta    = Date.parse(dt_inicio).strftime("%Y-%m") rescue Time.current.strftime("%Y-%m")
    key_custom   = "#{empresa_slug}/#{mes_pasta}/#{SecureRandom.hex(4)}-#{nome}"
    pacote.arquivo.attach(io: StringIO.new(conteudo), filename: nome,
                          content_type: pacote_api.mime, key: key_custom)
    pacote.save!
    redirect_to pacotes_path, notice: "Pacote gerado e salvo (#{nome})."
  rescue => e
    Rails.logger.error("[PacotesFiscais#gerar] #{e.class} - #{e.message}")
    redirect_to pacotes_path, alert: "Falha ao gerar o pacote: #{e.message}"
  end

  # Baixa o pacote SALVO (sem chamar o provedor).
  def baixar
    unless @pacote.arquivo.attached?
      return redirect_to pacotes_path, alert: "Arquivo do pacote não encontrado."
    end
    send_data @pacote.conteudo, filename: @pacote.nome_arquivo,
              type: @pacote.mime.presence || "application/octet-stream", disposition: "attachment"
  end

  # Envia o pacote SALVO ao contador por e-mail (Brevo), sem regerar.
  def enviar_contador
    if @config.email_xml.blank?
      return redirect_to pacotes_path, alert: "Cadastre o e-mail do contador na Configuração fiscal."
    end
    unless @pacote.arquivo.attached?
      return redirect_to pacotes_path, alert: "Arquivo do pacote não encontrado."
    end

    empresa = current_collaborator.empresa
    ContadorMailer.enviar_notas(
      destinatarios:  @config.email_xml,
      remetente:      "nao-responda@mail.moveisrosa.shop",
      assunto:        "Notas fiscais #{empresa&.nome} — #{@pacote.periodo_inicio} a #{@pacote.periodo_fim}",
      corpo:          "Segue em anexo o pacote de notas fiscais de #{empresa&.nome} " \
                      "referente ao período de #{@pacote.periodo_inicio} a #{@pacote.periodo_fim}.",
      anexo_nome:     @pacote.nome_arquivo,
      anexo_conteudo: @pacote.conteudo,
      anexo_mime:     @pacote.mime
    ).deliver_now

    @pacote.update(enviado_contador_em: Time.current, email_destino: @config.email_xml)
    redirect_to pacotes_path, notice: "Pacote enviado para #{@config.email_xml}."
  rescue => e
    Rails.logger.error("[PacotesFiscais#enviar_contador] #{e.class} - #{e.message}")
    redirect_to pacotes_path, alert: "Falha ao enviar o e-mail: #{e.message}"
  end

  # Exclui o pacote salvo (para regerar quando precisar).
  def destroy
    @pacote.destroy
    redirect_to pacotes_path, notice: "Pacote excluído."
  end

  private

  def set_config
    @config = FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)
  end

  def set_pacote
    @pacote = PacoteFiscal.da_empresa(current_collaborator.cod_empresa).find(params[:id])
  end

  def pacotes_path
    collaborators_backoffice_pacotes_fiscais_path
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
