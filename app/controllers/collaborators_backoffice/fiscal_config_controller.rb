class CollaboratorsBackoffice::FiscalConfigController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_config

  def show
  end

  def edit
  end

  def update
    @config.assign_attributes(config_params)

    # TRAVA DE PRODUCAO: so deixa salvar com ambiente=producao quando os
    # pre-requisitos estao prontos (plano ativo, certificado valido, tokens e,
    # p/ quem emite NFC-e, CSC de producao). Evita virar p/ producao "no
    # escuro" e emitir nota real sem estar apto. Em homologacao, salva livre.
    if @config.ambiente == "producao" && @config.ambiente_changed?
      pendencias = pendencias_para_producao
      if pendencias.any?
        @config.ambiente = @config.ambiente_was # nao vira p/ producao
        flash.now[:alert] = "Não é possível ativar Produção ainda. Pendências: #{pendencias.join(' | ')}"
        render :edit, status: :unprocessable_entity and return
      end
    end

    if @config.save
      redirect_to collaborators_backoffice_fiscal_config_path,
                  notice: "Configuração fiscal salva."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET .../fiscal_config/checar_producao — roda as checagens de prontidão para
  # PRODUCAO e devolve JSON (lista de pendencias). A tela chama ao selecionar
  # "Produção" no ambiente, para avisar ANTES de salvar.
  def checar_producao
    unless @config&.persisted?
      render json: { pronto: false, pendencias: ["Salve a configuração fiscal primeiro."] }
      return
    end
    pend = pendencias_para_producao
    render json: { pronto: pend.empty?, pendencias: pend }
  rescue => e
    Rails.logger.error("[FiscalConfig#checar_producao] #{e.class} - #{e.message}")
    render json: { pronto: false, pendencias: ["Falha ao checar: #{e.message}"] }
  end

  # GET .../fiscal_config/testar_conexao — valida a comunicação com o provedor
  # usando os tokens cadastrados (BuscarEmpresa, que exige Token + UserToken e
  # não emite nada). Devolve JSON: ok + dados da empresa ou a mensagem de erro.
  def testar_conexao
    unless @config&.persisted?
      render json: { ok: false, mensagem: "Salve a configuração fiscal primeiro." }
      return
    end
    if @config.provedor.to_s != "brasilnfe"
      render json: { ok: false, mensagem: "Teste disponível apenas para o provedor Brasil NFe." }
      return
    end
    faltando = []
    faltando << "Token da empresa" if @config.brasilnfe_token_efetivo.blank?
    faltando << "Token pessoal (UserToken)" if @config.brasilnfe_user_token_efetivo.blank?
    if faltando.any?
      render json: { ok: false, mensagem: "Cadastre: #{faltando.join(' e ')}." }
      return
    end

    resp = FiscalService.new(@config).buscar_empresa
    erro = resp["Error"].to_s
    http = resp["_http_status"].to_i
    # Sucesso = veio CNPJ/razão da empresa e sem erro de auth.
    cnpj  = resp["CNPJ"].presence
    razao = resp["RzSocial"].presence || resp["NmFantasia"].presence

    if erro.blank? && http < 400 && (cnpj || razao)
      render json: {
        ok: true,
        mensagem: "Comunicação validada com a Brasil NFe.",
        empresa: { cnpj: cnpj, razao_social: razao,
                   ie: resp["IE"].presence, crt: resp["CRT"],
                   ambiente: @config.producao? ? "Produção" : "Homologação" }
      }
    else
      render json: {
        ok: false,
        mensagem: erro.presence ||
                  (http >= 400 ? "Falha de autenticação (HTTP #{http}). Verifique os tokens." :
                                 "Não foi possível validar — resposta sem dados da empresa.")
      }
    end
  rescue FiscalService::NaoConfigurado => e
    render json: { ok: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[FiscalConfig#testar_conexao] #{e.class} - #{e.message}")
    render json: { ok: false, mensagem: "Falha ao testar a conexão: #{e.message}" }
  end

  # POST .../fiscal_config/enviar_certificado — upload do certificado A1
  # (.pfx/.p12) + senha para a Brasil NFe (AlterarCertificado). A senha NAO e
  # persistida no nosso banco (a Brasil NFe guarda). Grava a validade retornada
  # em certificado_validade para exibir no painel.
  def enviar_certificado
    arquivo = params[:certificado_arquivo]
    senha   = params[:certificado_senha].to_s

    # UploadedFile#blank? e SEMPRE false (ate para 0 bytes), entao validamos pela
    # presenca do objeto e pelo CONTEUDO lido.
    unless arquivo.respond_to?(:read)
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "Selecione o arquivo do certificado (.pfx ou .p12)." and return
    end
    if senha.strip.empty?
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "Informe a senha do certificado." and return
    end
    nome = arquivo.original_filename.to_s
    unless nome.downcase.end_with?(".pfx", ".p12")
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "Formato inválido. Envie um certificado A1 (.pfx ou .p12)." and return
    end
    unless @config&.persisted?
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "Salve a configuração fiscal antes de enviar o certificado." and return
    end
    if @config.brasilnfe_token_efetivo.blank? || @config.brasilnfe_user_token_efetivo.blank?
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "Cadastre o Token da empresa e o Token pessoal (UserToken) antes de enviar o certificado." and return
    end

    conteudo = arquivo.read.to_s
    if conteudo.bytesize.zero?
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "O arquivo do certificado está vazio. Selecione um .pfx/.p12 válido." and return
    end

    base64 = Base64.strict_encode64(conteudo)
    resultado = FiscalService.new(@config).alterar_certificado(base64: base64, senha: senha)

    if resultado.sucesso?
      # Grava a validade retornada e um nome de referencia (sem a senha).
      attrs = { certificado_nome: nome }
      attrs[:certificado_validade] = resultado.data_expiracao if resultado.data_expiracao
      @config.update(attrs)

      aviso = resultado.avisos.present? ? " Avisos: #{resultado.avisos.join('; ')}." : ""
      validade = resultado.data_expiracao ? " Validade: #{resultado.data_expiracao.strftime('%d/%m/%Y')}." : ""
      redirect_to collaborators_backoffice_fiscal_config_path,
                  notice: "Certificado enviado com sucesso.#{validade}#{aviso}"
    else
      redirect_to edit_collaborators_backoffice_fiscal_config_path,
                  alert: "Não foi possível enviar o certificado: #{resultado.mensagem || 'verifique o arquivo e a senha.'}"
    end
  rescue FiscalService::NaoConfigurado => e
    redirect_to edit_collaborators_backoffice_fiscal_config_path, alert: e.message
  rescue => e
    Rails.logger.error("[FiscalConfig#enviar_certificado] #{e.class} - #{e.message}")
    redirect_to edit_collaborators_backoffice_fiscal_config_path,
                alert: "Falha ao enviar o certificado: #{e.message}"
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

  # GET .../fiscal_config/verificar_certificado — verifica o certificado digital
  # ja cadastrado da empresa no provedor e devolve JSON (validade/expirado).
  def verificar_certificado
    unless @config&.persisted? && @config.ativo?
      render json: { sucesso: false, mensagem: "Configuração fiscal ausente ou inativa." }
      return
    end
    unless @config.brasilnfe_user_token_efetivo.present?
      render json: { sucesso: false, mensagem: "Cadastre o Token pessoal (UserToken) para verificar o certificado." }
      return
    end

    cert = FiscalService.new(@config).verificar_certificado
    render json: {
      sucesso:        cert.sucesso?,
      valido:         cert.valido?,
      expirado:       cert.expirado?,
      data_expiracao: cert.data_expiracao&.strftime("%d/%m/%Y"),
      dias_para_expirar: cert.dias_para_expirar,
      proximo_vencimento: cert.proximo_vencimento?,
      avisos:         cert.avisos,
      mensagem:       cert.mensagem
    }
  rescue FiscalService::NaoConfigurado => e
    render json: { sucesso: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[FiscalConfig#verificar_certificado] #{e.class} - #{e.message}")
    render json: { sucesso: false, mensagem: "Falha ao verificar o certificado: #{e.message}" }
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

  # GET .../fiscal_config/consultar_numeracao — consulta no PROVEDOR a serie e o
  # proximo numero cadastrados (por modelo e ambiente) e devolve JSON para a
  # tela preencher os campos. Serve para o usuario VER o que o provedor usa hoje
  # (que ate agora era automatico) e trazer para a configuracao.
  def consultar_numeracao
    unless @config&.persisted? && @config.ativo?
      render json: { ok: false, mensagem: "Configuração fiscal ausente ou inativa." }
      return
    end
    if @config.provedor.to_s != "brasilnfe"
      render json: { ok: false, mensagem: "Disponível apenas para o provedor Brasil NFe." }
      return
    end

    resp = FiscalService.new(@config).consultar_numeracao
    erro = resp["Error"].to_s
    if erro.present?
      render json: { ok: false, mensagem: erro }
      return
    end

    # Ambiente atual (1 producao / 2 homologacao) para filtrar as numeracoes.
    amb_atual = @config.producao? ? 1 : 2

    numeracoes = Array(resp["Numeracoes"]).map do |n|
      {
        modelo:   n["ModeloDocumento"].to_i,
        serie:    n["Serie"].to_s,
        numero:   n["Numero"].to_i,
        ambiente: n["TipoAmbiente"].to_i,
        padrao:   n["Padrao"] == true
      }
    end

    # Melhor numeracao (padrao, ou a de maior numero) por modelo no ambiente atual.
    def_por_modelo = ->(modelo) do
      candidatas = numeracoes.select { |n| n[:modelo] == modelo && n[:ambiente] == amb_atual }
      candidatas.detect { |n| n[:padrao] } || candidatas.max_by { |n| n[:numero] }
    end

    render json: {
      ok: true,
      ambiente: @config.producao? ? "Produção" : "Homologação",
      numeracoes: numeracoes,
      sugestao: {
        nfe:  def_por_modelo.call(55),
        nfce: def_por_modelo.call(65)
      }
    }
  rescue FiscalService::NaoConfigurado => e
    render json: { ok: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[FiscalConfig#consultar_numeracao] #{e.class} - #{e.message}")
    render json: { ok: false, mensagem: "Falha ao consultar a numeração: #{e.message}" }
  end

  # POST .../fiscal_config/atualizar_numeracao — define/ajusta no PROVEDOR a serie
  # e o proximo numero de um modelo (55/65), e reflete nos campos locais do
  # FiscalConfig. E a forma SEGURA de "passar o numero": o provedor continua
  # sendo a fonte de verdade da sequencia (evita chave duplicada).
  def atualizar_numeracao
    modelo = params[:modelo].to_i
    serie  = params[:serie].to_s.strip
    numero = params[:numero].to_i

    unless [55, 65].include?(modelo)
      render json: { ok: false, mensagem: "Modelo inválido (use 55 ou 65)." }
      return
    end
    if serie.blank? || numero <= 0
      render json: { ok: false, mensagem: "Informe a série e um número maior que zero." }
      return
    end
    unless @config&.persisted? && @config.ativo?
      render json: { ok: false, mensagem: "Configuração fiscal ausente ou inativa." }
      return
    end
    if @config.provedor.to_s != "brasilnfe"
      render json: { ok: false, mensagem: "Disponível apenas para o provedor Brasil NFe." }
      return
    end

    resp = FiscalService.new(@config).atualizar_numeracao(
      modelo: modelo, serie: serie, numero: numero, padrao: true
    )
    erro = resp["Error"].to_s
    if erro.present?
      render json: { ok: false, mensagem: erro }
      return
    end

    # Reflete localmente (serie + proximo numero) para o painel e a emissao.
    if modelo == 65
      @config.update_columns(serie_nfce: serie.to_i, proximo_numero_nfce: numero)
    else
      @config.update_columns(serie_nfe: serie.to_i, proximo_numero_nfe: numero)
    end

    render json: {
      ok: true,
      mensagem: "Numeração atualizada no provedor para o modelo #{modelo} (série #{serie}, próximo número #{numero})."
    }
  rescue FiscalService::NaoConfigurado => e
    render json: { ok: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[FiscalConfig#atualizar_numeracao] #{e.class} - #{e.message}")
    render json: { ok: false, mensagem: "Falha ao atualizar a numeração: #{e.message}" }
  end

  private

  # Lista de PENDENCIAS que impedem operar em PRODUCAO. Vazia = pronto.
  # Ordem: credenciais locais -> plano no provedor -> certificado -> CSC (NFC-e).
  # As chamadas a API sao tolerantes a falha (nao derrubam; viram pendencia).
  def pendencias_para_producao
    pend = []

    # 1) Credenciais locais (sem elas nem da pra consultar o provedor).
    pend << "cadastre o Token da empresa" if @config.brasilnfe_token_efetivo.blank?
    pend << "cadastre o Token pessoal (UserToken)" if @config.brasilnfe_user_token_efetivo.blank?

    # Provedor diferente de brasilnfe: sem checagens de API (nada a validar aqui).
    return pend unless @config.provedor.to_s == "brasilnfe"
    # Sem credenciais nao adianta chamar a API — ja retorna as pendencias acima.
    return pend if pend.any?

    service = FiscalService.new(@config)

    # 2) Plano/assinatura ativo na Brasil NFe (ConsultarServicos).
    begin
      resp = service.consultar_servicos
      servicos = Array(resp["Servicos"])
      algum_ativo = servicos.any? { |s| s.is_a?(Hash) && (s["Ativo"] == true) }
      erro = resp["Error"].presence || Array(resp["erros"]).map { |e| e.is_a?(Hash) ? e["descricao"] : e }.compact.join("; ").presence
      if resp["status"].to_i == 2 || erro.present?
        pend << "verifique a assinatura na Brasil NFe (#{erro || 'serviços indisponíveis'})"
      elsif servicos.any? && !algum_ativo
        pend << "nenhum serviço/plano ativo na Brasil NFe (contrate um plano)"
      end
    rescue => e
      pend << "não foi possível confirmar o plano na Brasil NFe (#{e.message})"
    end

    # 3) Certificado digital valido (nao expirado).
    begin
      cert = service.verificar_certificado
      if !cert.sucesso?
        pend << "certificado: #{cert.mensagem || 'não foi possível verificar'}"
      elsif cert.expirado?
        pend << "certificado digital expirado — envie um certificado válido"
      end
    rescue => e
      pend << "não foi possível verificar o certificado (#{e.message})"
    end

    # 4) CSC de PRODUCAO (obrigatorio para NFC-e modelo 65).
    if @config.csc_id_producao.to_s.strip.blank? || @config.csc_token_producao.to_s.strip.blank?
      pend << "cadastre o CSC de produção (ID + token) — exigido para NFC-e"
    end

    pend
  end

  # Config unica por empresa: acha a existente ou monta uma nova (sem salvar).
  def set_config
    @config = FiscalConfig.find_or_initialize_by(cod_empresa: current_collaborator.cod_empresa)
  end

  def config_params
    permitidos = params.require(:fiscal_config).permit(
      :ambiente, :regime_tributario, :crt,
      :serie_nfe, :serie_nfce, :proximo_numero_nfe, :proximo_numero_nfce,
      :certificado_nome, :certificado_validade,
      :provedor, :ativo, :email_xml,
      # Credenciais Brasil NFe (token da empresa + UserToken) + CSC por ambiente.
      :brasilnfe_token, :brasilnfe_user_token,
      :csc_id_producao, :csc_token_producao, :csc_id_homologacao, :csc_token_homologacao
    )
    # Campos de credencial: em branco NAO apaga o valor ja salvo (o usuario deixa
    # vazio quando nao quer trocar). So atualiza quando vem preenchido. Assim a
    # tela pode exibir o campo vazio (nao reexpor o segredo) sem zerar o guardado.
    %i[brasilnfe_token brasilnfe_user_token
       csc_token_producao csc_token_homologacao].each do |campo|
      permitidos.delete(campo) if permitidos[campo].blank?
    end
    permitidos.merge(cod_empresa: current_collaborator.cod_empresa)
  end

  # A tela de Configuracao e o que ATIVA o modulo fiscal de uma empresa, entao
  # nao pode exigir modulo ja ativo (paradoxo). Fica restrita ao super_admin
  # (quem configura empresas), via SUPER_ADMIN_ONLY_RESOURCES 'fiscal_config'.
  def autorizar_fiscal!
    # Config exige o modulo HABILITADO no cadastro (parametro), mas NAO exige o
    # FiscalConfig ativo — e justamente a tela que cria/ativa a configuracao.
    unless empresa_modulo_fiscal_habilitado? && access_control.can_view?("fiscal_config")
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
