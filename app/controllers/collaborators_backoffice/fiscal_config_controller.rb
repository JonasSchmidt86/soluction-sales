class CollaboratorsBackoffice::FiscalConfigController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_config

  def show
  end

  def edit
  end

  def update
    if @config.update(config_params)
      redirect_to collaborators_backoffice_fiscal_config_path,
                  notice: "Configuração fiscal salva."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET .../fiscal_config/status_sefaz?modelo=55 — consulta o status da SEFAZ
  # (sempre em producao) e devolve JSON para a tela exibir sem recarregar.
  def status_sefaz
    modelo = params[:modelo].presence&.to_i || 55

    unless @config&.persisted? && @config.ativo?
      render json: { operante: false, mensagem: "Configuração fiscal ausente ou inativa." }
      return
    end

    status = FiscalService.new(@config).consultar_status(modelo: modelo)
    render json: {
      operante: status.operante?,
      codigo:   status.codigo,
      mensagem: status.mensagem,
      uf:       status.uf,
      ambiente: status.ambiente,
      modelo:   modelo
    }
  rescue FiscalService::NaoConfigurado => e
    render json: { operante: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[FiscalConfig#status_sefaz] #{e.class} - #{e.message}")
    render json: { operante: false, mensagem: "Falha ao consultar: #{e.message}" }
  end

  # GET .../fiscal_config/consultar_cadastro?uf=PR&documento=... — consulta o
  # cadastro do contribuinte na SEFAZ e devolve JSON para a tela.
  def consultar_cadastro
    uf  = params[:uf].to_s.strip
    doc = params[:documento].to_s.gsub(/\D/, "")

    if uf.empty? || doc.empty?
      render json: { sucesso: false, mensagem: "Informe UF e CPF/CNPJ." }
      return
    end
    unless @config&.persisted? && @config.ativo?
      render json: { sucesso: false, mensagem: "Configuração fiscal ausente ou inativa." }
      return
    end

    cad = FiscalService.new(@config).consultar_cadastro(uf: uf, documento: doc)

    # Verifica se ja existe pessoa com esse documento, para oferecer "abrir" ou
    # "cadastrar". Monta tambem os params de pre-preenchimento do novo cadastro.
    pessoa = Pessoa.select(:cod_pessoa).find_by(cpf_cnpj: doc)
    e = cad.endereco || {}

    render json: {
      sucesso:         cad.sucesso?,
      habilitado:      cad.habilitado?,
      situacao:        cad.situacao,
      ie:              cad.ie,
      razao_social:    cad.razao_social,
      nome_fantasia:   cad.nome_fantasia,
      regime:          cad.regime,
      cnae:            cad.cnae,
      credenciado_nfe: cad.credenciado_nfe?,
      credenciado_cte: cad.credenciado_cte?,
      uf:              cad.uf,
      fonte:           cad.fonte,
      data_inicio:     cad.data_inicio,
      data_baixa:      cad.data_baixa,
      data_alteracao:  cad.data_alteracao,
      endereco:        cad.endereco_linha,
      contato:         cad.contato,
      mensagem:        cad.mensagem,
      # Suporte ao atalho de cadastro de pessoa:
      pessoa_existe:   pessoa.present?,
      cod_pessoa:      pessoa&.cod_pessoa,
      prefill: {
        tipo:        "J",
        cpf_cnpj:    doc,
        nome:        cad.razao_social,
        apelido:     cad.nome_fantasia,
        rg_ie:       cad.ie,
        cep:         e["cep"],
        endereco:    e["logradouro"],
        numero:      e["numero"],
        bairro:      e["bairro"],
        complemento: e["complemento"],
        telefone:    cad.contato && cad.contato["telefone"],
        email:       cad.contato && cad.contato["email"]
      }.compact
    }
  rescue FiscalService::NaoConfigurado => e
    render json: { sucesso: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[FiscalConfig#consultar_cadastro] #{e.class} - #{e.message}")
    render json: { sucesso: false, mensagem: "Falha ao consultar: #{e.message}" }
  end

  # GET .../fiscal_config/exportar — tela de exportação fiscal por período.
  def exportar
  end

  # POST .../fiscal_config/exportar_download — baixa o pacote (zip/xlsx) do
  # período informado via ObterArquivosPorPeriodo.
  def exportar_download
    unless @config&.persisted? && @config.ativo?
      redirect_to exportar_collaborators_backoffice_fiscal_config_path, alert: "Configuração fiscal ausente ou inativa."
      return
    end

    dt_inicio = params[:dt_inicio].presence
    dt_fim    = params[:dt_fim].presence
    if dt_inicio.blank? || dt_fim.blank?
      redirect_to exportar_collaborators_backoffice_fiscal_config_path, alert: "Informe o período (início e fim)."
      return
    end

    tipo_arquivo = params[:tipo_arquivo].presence&.to_i || 1 # 0 PDF, 1 XML, 2 Excel
    tipo_nota    = params[:tipo_nota].presence&.to_i || 1    # 1 saídas, 2 entradas, 3 ambos
    incluir_cce  = ActiveModel::Type::Boolean.new.cast(params[:incluir_cce])

    pacote = FiscalService.new(@config).obter_arquivos_periodo(
      dt_inicio: dt_inicio, dt_fim: dt_fim,
      tipo_arquivo: tipo_arquivo, tipo_nota: tipo_nota, incluir_cce: incluir_cce
    )

    if pacote.sucesso?
      send_data pacote.conteudo,
                filename: "fiscal-#{dt_inicio}_a_#{dt_fim}.#{pacote.extensao}",
                type: pacote.mime, disposition: "attachment"
    else
      redirect_to exportar_collaborators_backoffice_fiscal_config_path,
                  alert: "Não foi possível gerar o pacote: #{pacote.erro}"
    end
  rescue => e
    Rails.logger.error("[FiscalConfig#exportar_download] #{e.class} - #{e.message}")
    redirect_to exportar_collaborators_backoffice_fiscal_config_path, alert: "Falha ao exportar: #{e.message}"
  end

  # POST .../fiscal_config/enviar_contador — gera o pacote do periodo (mesmo do
  # exportar_download) e ENVIA por e-mail ao contador (via Brevo), em vez de
  # baixar. O destinatario e o email_xml cadastrado na config.
  def enviar_contador
    unless @config&.persisted? && @config.ativo?
      redirect_to exportar_collaborators_backoffice_fiscal_config_path, alert: "Configuração fiscal ausente ou inativa."
      return
    end
    if @config.email_xml.blank?
      redirect_to exportar_collaborators_backoffice_fiscal_config_path,
                  alert: "Cadastre o e-mail do contador na Configuração fiscal antes de enviar."
      return
    end

    dt_inicio = params[:dt_inicio].presence
    dt_fim    = params[:dt_fim].presence
    if dt_inicio.blank? || dt_fim.blank?
      redirect_to exportar_collaborators_backoffice_fiscal_config_path, alert: "Informe o período (início e fim)."
      return
    end

    tipo_arquivo = params[:tipo_arquivo].presence&.to_i || 1
    tipo_nota    = params[:tipo_nota].presence&.to_i || 1
    incluir_cce  = ActiveModel::Type::Boolean.new.cast(params[:incluir_cce])

    pacote = FiscalService.new(@config).obter_arquivos_periodo(
      dt_inicio: dt_inicio, dt_fim: dt_fim,
      tipo_arquivo: tipo_arquivo, tipo_nota: tipo_nota, incluir_cce: incluir_cce
    )

    unless pacote.sucesso?
      redirect_to exportar_collaborators_backoffice_fiscal_config_path,
                  alert: "Não foi possível gerar o pacote: #{pacote.erro}"
      return
    end

    empresa = current_collaborator.empresa
    nome_arquivo = "fiscal-#{dt_inicio}_a_#{dt_fim}.#{pacote.extensao}"
    ContadorMailer.enviar_notas(
      destinatarios:  @config.email_xml,
      remetente:      "nao-responda@mail.moveisrosa.shop",
      assunto:        "Notas fiscais #{empresa&.nome} — #{dt_inicio} a #{dt_fim}",
      corpo:          "Segue em anexo o pacote de notas fiscais de #{empresa&.nome} " \
                      "referente ao período de #{dt_inicio} a #{dt_fim}.",
      anexo_nome:     nome_arquivo,
      anexo_conteudo: pacote.conteudo,
      anexo_mime:     pacote.mime
    ).deliver_now

    redirect_to exportar_collaborators_backoffice_fiscal_config_path,
                notice: "Pacote enviado para #{@config.email_xml}."
  rescue => e
    Rails.logger.error("[FiscalConfig#enviar_contador] #{e.class} - #{e.message}")
    redirect_to exportar_collaborators_backoffice_fiscal_config_path,
                alert: "Falha ao enviar o e-mail: #{e.message}"
  end

  private

  # Config unica por empresa: acha a existente ou monta uma nova (sem salvar).
  def set_config
    @config = FiscalConfig.find_or_initialize_by(cod_empresa: current_collaborator.cod_empresa)
  end

  def config_params
    params.require(:fiscal_config).permit(
      :ambiente, :regime_tributario, :crt,
      :serie_nfe, :serie_nfce, :proximo_numero_nfe, :proximo_numero_nfce,
      :csc_id, :csc_token, :certificado_nome, :certificado_validade,
      :provedor, :ativo, :email_xml
    ).merge(cod_empresa: current_collaborator.cod_empresa)
  end

  # A tela de Configuracao e o que ATIVA o modulo fiscal de uma empresa, entao
  # nao pode exigir modulo ja ativo (paradoxo). Fica restrita ao super_admin
  # (quem configura empresas), via SUPER_ADMIN_ONLY_RESOURCES 'fiscal_config'.
  def autorizar_fiscal!
    unless access_control.can_view?("fiscal_config")
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
