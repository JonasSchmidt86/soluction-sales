class CollaboratorsBackoffice::NotasRecebidasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_nota, only: [:importar]

  # Painel UNICO de notas de ENTRADA recebidas (gravadas em NotaRecebida).
  # A busca na SEFAZ (ver_entradas) grava os registros aqui; a tabela e a lista.
  def index
    @cod_empresa = current_collaborator.cod_empresa
    @inicio, @fim = periodo
    @config = FiscalConfig.find_by(cod_empresa: @cod_empresa)

    escopo = NotaRecebida.da_empresa(@cod_empresa)
                         .where(data_emissao: @inicio.beginning_of_day..@fim.end_of_day)
    escopo = escopo.where(status_sefaz: params[:status]) if params[:status].present?
    if params[:integrado] == "1"
      escopo = escopo.integradas
    elsif params[:integrado] == "0"
      escopo = escopo.nao_integradas
    end
    # Filtro por TIPO de documento: mercadoria (NF-e 55) x servico (demais, ex.
    # NFS-e / telecom modelo 10). @tipo guarda a selecao para a view.
    @tipo = params[:tipo].presence
    if @tipo == "mercadoria"
      escopo = escopo.where(modelo: 55)
    elsif @tipo == "servico"
      escopo = escopo.where("modelo IS NULL OR modelo <> 55")
    end

    @notas = escopo.includes(:compra).recentes.page(params[:page])
    @alertas_canceladas = NotaRecebida.da_empresa(@cod_empresa).integradas.canceladas
  end

  # POST .../notas_recebidas/ver_entradas — busca as entradas do periodo na SEFAZ
  # e REGISTRA (so dados, sem baixar XML) as novas em NotaRecebida. Dedupe por
  # chave: as ja existentes nao sao duplicadas. Volta para a lista (index).
  def ver_entradas
    inicio, fim = periodo
    res = Fiscal::NotasRecebidasService.new(current_collaborator.empresa)
                                       .registrar_periodo!(dt_inicio: inicio, dt_fim: fim)
    if res.erro
      redirect_to notas_recebidas_path(filtros), alert: "Falha ao buscar na SEFAZ: #{res.mensagem}"
    else
      redirect_to notas_recebidas_path(filtros), notice: res.mensagem
    end
  end

  # POST .../notas_recebidas/salvar_chave?chave=... — grava na lista (NotaRecebida)
  # uma nota consultada por chave, SO com os dados (sem baixar XML). Dedupe.
  def salvar_chave
    chave = params[:chave].to_s.gsub(/\D/, "")
    if chave.length < 20
      redirect_to notas_recebidas_path(filtros), alert: "Chave inválida." and return
    end
    config = FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)
    unless config&.ativo?
      redirect_to notas_recebidas_path(filtros), alert: "Empresa sem configuração fiscal ativa." and return
    end

    # Consulta na SEFAZ para pegar os dados (numero/serie/situacao) e gravar.
    consulta = FiscalService.new(config).consultar(chave: chave, modelo: 0)
    resumo = {
      "Numero"          => consulta&.numero,
      "Serie"           => consulta&.serie,
      "ModeloDocumento" => nil, # a consulta nao traz modelo confiavel; fica nil
      "Status"          => nil
    }
    nota = Fiscal::NotasRecebidasService.new(current_collaborator.empresa).registrar_dados!(chave, resumo)
    if nota
      redirect_to notas_recebidas_path(filtros), notice: "Nota #{chave} salva na lista."
    else
      redirect_to notas_recebidas_path(filtros), alert: "Não foi possível salvar a nota."
    end
  rescue => e
    Rails.logger.error("[NotasRecebidas#salvar_chave] #{e.class} - #{e.message}")
    redirect_to notas_recebidas_path(filtros), alert: "Falha ao salvar: #{e.message}"
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
      conteudo = arquivo.conteudo

      # Sanidade: garante que o binario decodificado e mesmo um PDF/XML. Se vier
      # corrompido (base64 malformado, JSON cru decodificado por engano etc.),
      # nao entrega um arquivo quebrado ao navegador — loga o inicio p/ diagnostico.
      if tipo == :pdf
        valido = conteudo.to_s.start_with?("%PDF")
      else
        amostra = conteudo.to_s[0, 200].to_s.lstrip
        valido = amostra.start_with?("<") # XML/declaracao <?xml ...?>
      end

      unless valido
        amostra = conteudo.to_s[0, 60].inspect
        Rails.logger.error("[NotasRecebidas#baixar_chave] conteudo invalido (tipo=#{tipo}, chave=#{chave}). Inicio: #{amostra}")
        redirect_to collaborators_backoffice_notas_recebidas_path,
                    alert: "O arquivo retornado pelo provedor veio em formato inesperado e não pôde ser aberto. Tente novamente; se persistir, avise o suporte (a resposta foi registrada no log)." and return
      end

      if tipo == :pdf
        send_data conteudo, filename: "danfe-#{chave}.pdf",
                  type: "application/pdf", disposition: "attachment"
      else
        send_data conteudo, filename: "nfe-#{chave}.xml",
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

  # POST .../notas_recebidas/importar_chave?chave=... — importa a nota DIRETO pela
  # chave: baixa o XML da SEFAZ, cria o XmlFile e leva a tela de montar a compra
  # (produtoxmls#new). Evita o vai-e-vem de baixar o XML no computador e subir em
  # xml_files manualmente. Grava a NotaRecebida (registro) no processo.
  def importar_chave
    chave = params[:chave].to_s.gsub(/\D/, "")
    if chave.length < 20
      redirect_to collaborators_backoffice_notas_recebidas_path, alert: "Chave inválida." and return
    end
    config = FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)
    unless config&.ativo?
      redirect_to collaborators_backoffice_notas_recebidas_path, alert: "Empresa sem configuração fiscal ativa." and return
    end

    nota = Fiscal::NotasRecebidasService.new(current_collaborator.empresa).importar_chave!(chave)
    if nota&.xml_file_id.present?
      redirect_to new_collaborators_backoffice_produtoxml_path(nota.xml_file_id)
    else
      redirect_to collaborators_backoffice_notas_recebidas_path(ver_entradas: 1, inicio: params[:inicio], fim: params[:fim]),
                  alert: "Não foi possível obter o XML desta nota para importar. Se for nota de serviço (NFS-e), ela não entra no fluxo de compra de mercadoria."
    end
  rescue => e
    Rails.logger.error("[NotasRecebidas#importar_chave] #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_notas_recebidas_path(ver_entradas: 1),
                alert: "Falha ao importar: #{e.message}"
  end

  # DELETE .../notas_recebidas/:id — remove o REGISTRO da nota da lista (nosso
  # banco). Nao afeta a SEFAZ nem a compra: se a nota ja virou compra, o registro
  # pode ser removido sem apagar a compra (so perde o vinculo de rastreio aqui).
  def destroy
    nota = NotaRecebida.da_empresa(current_collaborator.cod_empresa).find_by(cod_nota_recebida: params[:id])
    if nota.nil?
      redirect_to notas_recebidas_path(filtros), alert: "Nota não encontrada." and return
    end
    nota.destroy
    redirect_to notas_recebidas_path(filtros), notice: "Nota removida da lista."
  rescue => e
    Rails.logger.error("[NotasRecebidas#destroy] #{e.class} - #{e.message}")
    redirect_to notas_recebidas_path(filtros), alert: "Falha ao remover: #{e.message}"
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

  def set_nota
    @nota = NotaRecebida.da_empresa(current_collaborator.cod_empresa).find(params[:id])
  end

  def periodo
    ini = parse_data(params[:inicio]) || Date.today.beginning_of_month
    fim = parse_data(params[:fim])    || Date.today
    ini, fim = fim, ini if ini > fim
    [ini, fim]
  end

  # Filtros atuais (datas/tipo/status/integrado) para preservar na navegacao e
  # nos botoes. Exposto como helper para a view montar os links/forms.
  helper_method :filtros
  def filtros
    { inicio: params[:inicio], fim: params[:fim], status: params[:status],
      integrado: params[:integrado], tipo: params[:tipo] }.compact
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
