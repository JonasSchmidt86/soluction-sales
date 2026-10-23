class CollaboratorsBackoffice::NotasRecebidasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_nota, only: [:importar]

  # Painel de notas de ENTRADA recebidas de fornecedores (automatico via SEFAZ).
  def index
    @cod_empresa = current_collaborator.cod_empresa
    @inicio, @fim = periodo

    escopo = NotaRecebida.da_empresa(@cod_empresa)
                         .where(data_emissao: @inicio.beginning_of_day..@fim.end_of_day)
    escopo = escopo.where(status_sefaz: params[:status]) if params[:status].present?
    if params[:integrado] == "1"
      escopo = escopo.integradas
    elsif params[:integrado] == "0"
      escopo = escopo.nao_integradas
    end

    @notas = escopo.recentes.page(params[:page])

    # Alerta: notas que viraram compra mas foram CANCELADAS na SEFAZ.
    @alertas_canceladas = NotaRecebida.da_empresa(@cod_empresa).integradas.canceladas

    # Listagem AO VIVO da distribuicao (ObterNotasFiscais) — SO LEITURA, nao grava
    # NotaRecebida. Preenchida quando o usuario clica em "Ver entradas na SEFAZ"
    # (params[:ver_entradas]=1). Permite visualizar o que a Brasil NFe captou e
    # baixar XML/DANFE por chave, sem o automatismo de sincronizacao.
    @entradas_sefaz = nil
    @entradas_erro  = nil
    @config = FiscalConfig.find_by(cod_empresa: @cod_empresa)
    if params[:ver_entradas] == "1"
      @entradas_sefaz, @entradas_erro = listar_entradas_sefaz(@inicio, @fim)
    end
  end

  # Busca na SEFAZ as notas de entrada do periodo e grava as novas.
  def sincronizar
    inicio, fim = periodo
    res = Fiscal::NotasRecebidasService.new(current_collaborator.empresa)
                                       .sincronizar!(dt_inicio: inicio, dt_fim: fim)
    if res.erro
      redirect_to notas_recebidas_path(filtros), alert: "Falha ao buscar notas: #{res.mensagem}"
    else
      redirect_to notas_recebidas_path(filtros), notice: "Busca concluída: #{res.mensagem}"
    end
  end

  # Atualiza o status SEFAZ das notas ja conhecidas (detecta cancelamento).
  def sincronizar_status
    inicio, fim = periodo
    res = Fiscal::NotasRecebidasService.new(current_collaborator.empresa)
                                       .sincronizar!(dt_inicio: inicio, dt_fim: fim)
    redirect_to notas_recebidas_path(filtros),
                notice: "Status atualizado: #{res.mensagem}"
  end

  # GET .../notas_recebidas/consultar_chave?chave=... — CONSULTA (só ver) uma NF
  # pela chave na SEFAZ, SEM gravar nada (não cria NotaRecebida/XmlFile/compra).
  # Uso: rodar em paralelo com outro sistema sem risco de duplicar escrituração.
  def consultar_chave
    chave = params[:chave].to_s.gsub(/\D/, "")
    if chave.length < 20
      render json: { sucesso: false, mensagem: "Informe a chave de acesso da nota." }
      return
    end
    config = FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)
    unless config&.ativo?
      render json: { sucesso: false, mensagem: "Configuração fiscal ausente ou inativa." }
      return
    end

    consulta = FiscalService.new(config).consultar(chave: chave, modelo: 0)
    unless consulta&.encontrada?
      base = consulta&.mensagem.presence || "Nota não localizada na base da Brasil NFe."
      render json: { sucesso: false,
                     mensagem: "#{base} Notas de ENTRADA só aparecem após serem manifestadas/distribuídas para a sua conta." }
      return
    end

    render json: {
      sucesso:   true,
      chave:     chave,
      numero:    consulta.numero,
      serie:     consulta.serie,
      situacao:  consulta.situacao,
      protocolo: consulta.protocolo,
      mensagem:  consulta.mensagem
    }
  rescue FiscalService::NaoConfigurado => e
    render json: { sucesso: false, mensagem: e.message }
  rescue => e
    Rails.logger.error("[NotasRecebidas#consultar_chave] #{e.class} - #{e.message}")
    render json: { sucesso: false, mensagem: "Falha ao consultar: #{e.message}" }
  end

  # GET .../notas_recebidas/baixar_chave?chave=...&tipo=xml|pdf — DOWNLOAD manual
  # do arquivo (XML ou DANFE) pela chave. NÃO salva no ERP: só entrega o arquivo
  # para o navegador. So funciona para notas JA DISPONIVEIS na base do provedor
  # (entrada: notas ja manifestadas/distribuidas; saida: emitidas pela empresa).
  # Tenta ENTRADA (tipo 0) e, se vazio, SAIDA (tipo 1) — cobre os dois casos.
  def baixar_chave
    chave = params[:chave].to_s.gsub(/\D/, "")
    tipo  = params[:tipo].to_s == "pdf" ? :pdf : :xml
    # NF-e/NFC-e usam 44 digitos; NFS-e/telecom (modelo 10) usam chaves maiores.
    # Aceita qualquer chave com digitos suficientes (a API valida o resto).
    if chave.length < 20
      redirect_to collaborators_backoffice_notas_recebidas_path, alert: "Chave inválida." and return
    end
    config = FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)
    unless config&.ativo?
      redirect_to collaborators_backoffice_notas_recebidas_path, alert: "Empresa sem configuração fiscal ativa." and return
    end

    file_type = (tipo == :pdf ? 2 : 1)
    service = FiscalService.new(config)
    # tipo_documento preferido pelo parametro (0 entrada / 1 saida); se nao vier,
    # tenta entrada e cai para saida.
    tentativas = case params[:origem].to_s
                 when "saida"   then [1]
                 when "entrada" then [0]
                 else [0, 1]
                 end

    arquivo = nil
    tentativas.each do |td|
      arquivo = service.obter_arquivo(chave: chave, file_type: file_type, tipo_documento: td)
      break if arquivo&.sucesso?
    end

    if arquivo&.sucesso?
      if tipo == :pdf
        send_data arquivo.conteudo, filename: "danfe-#{chave}.pdf",
                  type: "application/pdf", disposition: "attachment"
      else
        send_data arquivo.conteudo, filename: "nfe-#{chave}.xml",
                  type: "application/xml", disposition: "attachment"
      end
    else
      redirect_to collaborators_backoffice_notas_recebidas_path,
                  alert: "Arquivo indisponível para esta chave. Se é uma nota de ENTRADA, ela só fica disponível após ser manifestada/distribuída para a sua conta na Brasil NFe. #{arquivo&.erro}".strip
    end
  rescue FiscalService::NaoConfigurado => e
    redirect_to collaborators_backoffice_notas_recebidas_path, alert: e.message
  rescue => e
    Rails.logger.error("[NotasRecebidas#baixar_chave] #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_notas_recebidas_path, alert: "Falha ao baixar: #{e.message}"
  end

  # Importar = levar ao fluxo de compra existente (produtoxmls#new monta a compra
  # a partir do XmlFile). Reusa toda a tela de conferencia atual.
  def importar
    if @nota.xml_file_id.blank?
      redirect_to notas_recebidas_path, alert: "Nota sem XML baixado para importar."
      return
    end
    redirect_to new_collaborators_backoffice_produtoxml_path(@nota.xml_file_id)
  end

  private

  # Lista as notas de ENTRADA do periodo direto da distribuicao (ObterNotasFiscais),
  # SEM gravar nada. Retorna [lista_de_hashes, erro_ou_nil]. Cada item: chave,
  # numero, serie, modelo, valor, emissor, cnpj_emissor, data_emissao, status.
  # So leitura — nao manifesta nem escritura (seguro rodar em paralelo com outro
  # sistema). A empresa precisa de config fiscal ativa.
  def listar_entradas_sefaz(inicio, fim)
    config = FiscalConfig.find_by(cod_empresa: @cod_empresa)
    return [nil, "Configuração fiscal ausente ou inativa."] unless config&.ativo?

    resp = Fiscal::BrasilNfeAdapter.new(config: config)
                                   .obter_notas(dt_inicio: inicio, dt_fim: fim, tipo_documento: 0)
    erro  = resp["Error"].to_s
    notas = resp["Notas"] || resp["notas"] || []

    # "Nao existe notas" = periodo vazio, nao e erro.
    if notas.empty? && erro.present? && !erro.downcase.include?("existe")
      return [nil, erro]
    end

    lista = Array(notas).map do |n|
      {
        chave:        (n["Chave"] || n["ChaveNF"] || n["chave"]).to_s.gsub(/\D/, ""),
        numero:       n["Numero"],
        serie:        n["Serie"],
        modelo:       n["ModeloDocumento"],
        valor:        n["Valor"],
        emissor:      n["NomeEmissor"] || n["NomeEmitente"] || n["EmitenteNome"],
        cnpj_emissor: n["CnpjEmissor"] || n["CnpjEmitente"],
        data_emissao: n["DtEmissao"] || n["DataEmissao"],
        status:       n["Status"]
      }
    end
    [lista, nil]
  rescue => e
    Rails.logger.error("[NotasRecebidas#listar_entradas_sefaz] #{e.class} - #{e.message}")
    [nil, "Falha ao consultar a SEFAZ: #{e.message}"]
  end

  def set_nota
    @nota = NotaRecebida.da_empresa(current_collaborator.cod_empresa).find(params[:id])
  end

  def periodo
    ini = parse_data(params[:inicio]) || Date.today.beginning_of_month
    fim = parse_data(params[:fim])    || Date.today
    ini, fim = fim, ini if ini > fim
    [ini, fim]
  end

  def filtros
    { inicio: params[:inicio], fim: params[:fim], status: params[:status], integrado: params[:integrado] }.compact
  end

  def parse_data(v)
    Date.parse(v) if v.present?
  rescue ArgumentError
    nil
  end

  def notas_recebidas_path(opts = {})
    collaborators_backoffice_notas_recebidas_path(opts)
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
