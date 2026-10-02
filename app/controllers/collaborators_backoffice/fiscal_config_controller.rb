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
      :provedor, :ativo
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
