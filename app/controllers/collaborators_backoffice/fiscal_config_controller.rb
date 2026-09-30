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
