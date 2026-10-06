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
