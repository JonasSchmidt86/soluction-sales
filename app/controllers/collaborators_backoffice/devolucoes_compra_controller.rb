class CollaboratorsBackoffice::DevolucoesCompraController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_compra
  before_action :set_rascunho, only: [:edit, :emitir]

  # GET .../compras/:compra_id/devolucao/new
  # Tela de revisao: itens espelhados do XML da compra, CFOP/natureza editaveis.
  #
  # Ciclo de vida (igual a NF de venda): nao cria uma segunda devolucao quando a
  # compra ja tem uma. Se ja ha NF AUTORIZADA, manda visualiza-la; se ha RASCUNHO
  # em elaboracao, reabre o editor (edit) em vez de criar outro documento.
  def new
    existente = ultimo_documento_devolucao
    if existente&.autorizada?
      redirect_to collaborators_backoffice_notas_avulsa_path(existente),
                  notice: "Esta compra já tem NF de devolução autorizada (##{existente.cod_documento_fiscal})." and return
    elsif existente && EM_ELABORACAO.include?(existente.status)
      redirect_to edit_collaborators_backoffice_compra_devolucao_path(@compra, documento_id: existente.cod_documento_fiscal),
                  notice: "Devolução em elaboração reaberta (##{existente.cod_documento_fiscal}). Confira e emita." and return
    end

    carregar_opcoes_view

    extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
    @itens = extractor.itens
    @chave_referencia = extractor.chave_referencia
    @tem_xml = extractor.tem_xml?

    # Pre-resolve, por item, o perfil (o do produto) e o CFOP pela regra desse
    # perfil para a operacao de devolucao. Sem regra, cai no CFOP do XML.
    # CFOP de cada item: regra do perfil do produto PARA A OPERACAO padrao
    # (devolucao de compra). Sem regra, fica em branco (usuario resolve). O CFOP
    # recalcula ao trocar a operacao do topo ou o perfil do item (via JS).
    resolver = Fiscal::CfopResolver.new(empresa: @compra.empresa, destino_uf: @compra.pessoa&.uf)
    @itens = @itens.map do |it|
      produto = Produto.find_by(cod_produto: it[:cod_produto])
      perfil  = produto&.perfil_tributario
      regra   = (@operacao_padrao && produto) ? resolver.regra_para(produto, @operacao_padrao) : nil
      cfop_regra = regra ? RegraFiscal.cfop_por_uf(regra.cfop_base, @compra.empresa&.uf, @compra.pessoa&.uf) : nil
      it.merge(
        cod_perfil_tributario: perfil&.cod_perfil_tributario,
        cfop_sugerido:         cfop_regra # nil = em branco quando nao ha regra
      )
    end

    if @itens.empty?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "A compra não tem itens para devolver."
    end
  end

  # GET .../compras/:compra_id/devolucao/edit?documento_id=
  # Reabre um RASCUNHO de devolucao ja salvo: reconstroi os itens (e os impostos
  # editados) a partir do snapshot persistido (documento_fiscal_item.dados_devolucao),
  # sem reler o XML. Reexibe a MESMA tela de devolucao (new) preenchida.
  def edit
    carregar_opcoes_view

    @documento        = @rascunho
    @itens            = itens_do_rascunho_para_view(@rascunho)
    @chave_referencia = @rascunho.chave_referenciada.presence ||
                        Fiscal::DevolucaoCompraExtractor.new(@compra).chave_referencia
    @tem_xml          = @itens.any? # ja temos os dados salvos; nao depende do XML

    # Cabecalho salvo para reexibir (operacao, finalidade, natureza, obs, transporte).
    @operacao_padrao = OperacaoFiscal.find_by(cod_operacao_fiscal: @rascunho.cod_operacao_fiscal_rascunho) ||
                       @operacao_padrao
    @finalidade_sel        = @rascunho.finalidade
    @info_adicional_sel    = @rascunho.info_adicional
    @info_adicional_fisco_sel = @rascunho.info_adicional_fisco
    @transporte_sel        = @rascunho.transporte || {}

    if @itens.empty?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "O rascunho de devolução não tem itens." and return
    end
    render :new
  end

  # GET .../compras/:compra_id/devolucao/baixar_xml
  # Baixa o XML da NOTA DE ENTRADA (compra) buscando no provedor pela chave
  # (ObterArquivoNotaFiscal, tipo documento = entrada). Util quando o XML local
  # nao esta disponivel (ex.: storage de producao).
  def baixar_xml
    chave = Fiscal::DevolucaoCompraExtractor.new(@compra).chave_referencia
    if chave.blank?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "Compra sem chave de NF-e para buscar o XML."
      return
    end

    config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
    if config.nil? || !config.ativo?
      redirect_to collaborators_backoffice_compra_path(@compra), alert: "Empresa sem configuração fiscal ativa."
      return
    end

    arquivo = FiscalService.new(config).obter_arquivo(chave: chave, file_type: 1, tipo_documento: 0)
    if arquivo.sucesso?
      send_data arquivo.conteudo, filename: "nfe-entrada-#{chave}.xml",
                type: "application/xml", disposition: "attachment"
    else
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "XML da entrada indisponível: #{arquivo.erro}"
    end
  rescue => e
    Rails.logger.error("[DevolucoesCompra#baixar_xml] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_compra_path(@compra), alert: "Falha ao obter o XML: #{e.message}"
  end

  # GET .../compras/:compra_id/devolucao/resolver_cfop?cod_produto=&cod_operacao_fiscal=
  # Resolve o CFOP de um produto para a operacao escolhida, pela regra fiscal do
  # perfil (destino = UF do fornecedor da compra). Sem regra (perfil + operacao),
  # retorna vazio e o CFOP fica em branco. Usado via AJAX ao trocar a operacao
  # (no topo ou por item).
  def resolver_cfop
    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "Devolucao de compra")
    produto  = Produto.find_by(cod_produto: params[:cod_produto])
    perfil   = PerfilTributario.find_by(cod_perfil_tributario: params[:cod_perfil_tributario])

    # CFOP vem da regra (perfil + operacao). Sem regra, retorna vazio (branco).
    cfop = nil
    if operacao && (perfil || produto)
      cfop = Fiscal::CfopResolver.new(empresa: @compra.empresa, destino_uf: @compra.pessoa&.uf)
                                 .cfop(produto, operacao, perfil: perfil)
    end

    render json: { cfop: cfop, origem: cfop.present? ? "regra" : "sem_regra" }
  rescue => e
    Rails.logger.error("[DevolucoesCompra#resolver_cfop] #{e.class} - #{e.message}")
    render json: { cfop: nil, origem: "erro" }
  end

  # POST .../compras/:compra_id/devolucao/validar
  # Valida o estado do form (itens marcados, CFOP, valores, IE do fornecedor,
  # transporte) e devolve as pendencias + marcadores por item, para o painel
  # bloquear o botao Emitir. Backend e a fonte de verdade.
  def validar
    res = validar_devolucao
    render json: { pendencias: res[:mensagens], marcadores: res[:marcadores],
                   ok: res[:mensagens].empty? }
  rescue => e
    Rails.logger.error("[DevolucoesCompra#validar] #{e.class} - #{e.message}")
    render json: { pendencias: ["Falha ao validar: #{e.message}"], marcadores: {}, ok: false }
  end

  # POST .../compras/:compra_id/devolucao
  def create
    # Revalidacao no BACKEND (nao depende so do JS): IE do fornecedor, CFOP,
    # valores, item marcado, transporte. Se houver pendencia, NAO emite.
    pend = validar_devolucao[:mensagens]
    if pend.any?
      redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                  alert: "Não é possível emitir. #{pend.join(' | ')}" and return
    end

    # Reaproveita a devolucao em elaboracao desta compra ao REEMITIR apos uma
    # rejeicao/erro: sem isso, cada tentativa pela tela de criacao gerava um
    # DocumentoFiscal novo (mesma devolucao virando varios registros). Usa o
    # documento_id (quando veio do edit) ou a ultima devolucao em elaboracao
    # da compra; nil = primeira emissao (o EmissorFiscal cria o documento).
    documento_existente = rascunho_existente || rascunho_em_elaboracao_da_compra

    documento = montar_emissor(documento: documento_existente).emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  notice: "NF-e de devolução autorizada. Chave: #{documento.chave_acesso}"
    else
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "Devolução #{documento.status}: #{documento.mensagem_sefaz}"
    end
  rescue DevolucaoInvalida,
         Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra), alert: e.message
  rescue => e
    Rails.logger.error("[DevolucoesCompra#create] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                alert: "Falha ao emitir devolução: #{e.message}"
  end

  # POST .../compras/:compra_id/devolucao/salvar_rascunho
  # Salva a devolucao como RASCUNHO editavel (sem emitir, sem SEFAZ). Persiste
  # os itens MARCADOS com o snapshot fiscal completo (impostos espelhados do XML
  # + edicoes manuais) em documento_fiscal_item.dados_devolucao, para reabrir a
  # tela exatamente como estava sem reler o XML. Reaproveita o rascunho existente
  # (documento_id) quando for uma re-gravacao.
  def salvar_rascunho
    # Reaproveita o rascunho indicado (documento_id, vindo do edit) ou, na falta,
    # o ultimo rascunho em elaboracao desta compra — evita criar duplicatas.
    documento = rascunho_existente || rascunho_em_elaboracao_da_compra

    # Base dos itens: num rascunho NOVO, espelha o XML da compra (extractor).
    # Ao RE-salvar um rascunho (edit), usa o snapshot ja persistido como base —
    # nao depende de reler o XML (que pode nao estar mais disponivel).
    if documento
      base = itens_do_rascunho_para_view(documento)
      chave = params[:chave_referencia].presence || documento.chave_referenciada
    else
      extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
      base = extractor.itens
      chave = params[:chave_referencia].presence || extractor.chave_referencia
    end

    itens = aplicar_edicoes(base)
    if itens.empty?
      redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                  alert: "Marque ao menos um item para salvar o rascunho." and return
    end

    operacao   = operacao_do_form
    finalidade = (params[:finalidade].presence || 4).to_i
    ActiveRecord::Base.transaction do
      if documento
        documento.update!(atributos_cabecalho_rascunho(operacao, finalidade, chave))
        documento.itens.delete_all
      else
        config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
        documento = DocumentoFiscal.create!(
          {
            cod_empresa:     @compra.cod_empresa,
            cod_compra:      @compra.cod_compra,
            modelo:          55,
            ambiente:        config&.ambiente || "homologacao",
            status:          "rascunho",
            cod_funcionario: current_collaborator.cod_funcionario,
            provedor:        config&.provedor
          }.merge(atributos_cabecalho_rascunho(operacao, finalidade, chave))
        )
      end
      gravar_itens_rascunho(documento, itens)
    end

    redirect_to collaborators_backoffice_notas_avulsas_path,
                notice: "Devolução salva como rascunho (##{documento.cod_documento_fiscal}). Edite e emita quando quiser."
  rescue => e
    Rails.logger.error("[DevolucoesCompra#salvar_rascunho] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                alert: "Falha ao salvar o rascunho: #{e.message}"
  end

  # POST .../compras/:compra_id/devolucao/emitir (documento_id no form)
  # Emite um RASCUNHO de devolucao. Primeiro RE-GRAVA o rascunho com as edicoes
  # atuais do form (assim o que e emitido == o que fica persistido), depois
  # emite reaproveitando o MESMO DocumentoFiscal (nao cria outro).
  def emitir
    # Dois caminhos de entrada:
    #  a) do EDITOR (form com itens): re-grava o rascunho com as edicoes e emite;
    #  b) da LISTA (botao Emitir, sem itens): emite direto o snapshot persistido.
    do_form = params[:itens].present?

    if do_form
      base       = itens_do_rascunho_para_view(@rascunho)
      itens      = aplicar_edicoes(base)
      operacao   = operacao_do_form
      finalidade = (params[:finalidade].presence || @rascunho.finalidade || 4).to_i
      chave      = params[:chave_referencia].presence || @rascunho.chave_referenciada
    else
      itens      = itens_do_rascunho_para_emissao(@rascunho)
      operacao   = OperacaoFiscal.find_by(cod_operacao_fiscal: @rascunho.cod_operacao_fiscal_rascunho) ||
                   OperacaoFiscal.find_by(nome: "Devolucao de compra")
      finalidade = (@rascunho.finalidade || 4).to_i
      chave      = @rascunho.chave_referenciada
    end

    if itens.empty?
      redirect_to edit_collaborators_backoffice_compra_devolucao_path(@compra, documento_id: @rascunho.cod_documento_fiscal),
                  alert: "Marque ao menos um item para emitir." and return
    end

    # Revalidacao backend (fonte de verdade) — so quando veio do form (tem params
    # para validar). Da lista, o snapshot ja foi validado ao salvar.
    if do_form
      pend = validar_devolucao[:mensagens]
      if pend.any?
        redirect_to edit_collaborators_backoffice_compra_devolucao_path(@compra, documento_id: @rascunho.cod_documento_fiscal),
                    alert: "Não é possível emitir. #{pend.join(' | ')}" and return
      end

      # Persiste as edicoes atuais no rascunho (itens + cabecalho) antes de emitir.
      ActiveRecord::Base.transaction do
        @rascunho.update!(atributos_cabecalho_rascunho(operacao, finalidade, chave))
        @rascunho.itens.delete_all
        gravar_itens_rascunho(@rascunho, itens)
      end
    end

    documento = montar_emissor(itens: itens, documento: @rascunho, operacao: operacao,
                               finalidade: finalidade, chave: chave,
                               transporte: @rascunho.transporte,
                               info_adicional: @rascunho.info_adicional,
                               info_adicional_fisco: @rascunho.info_adicional_fisco).emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  notice: "NF-e de devolução autorizada. Chave: #{documento.chave_acesso}"
    else
      redirect_to edit_collaborators_backoffice_compra_devolucao_path(@compra, documento_id: documento.cod_documento_fiscal),
                  alert: "Devolução #{documento.status}: #{documento.mensagem_sefaz}"
    end
  rescue DevolucaoInvalida,
         Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao,
         Fiscal::EmissorFiscal::JaAutorizada => e
    redirect_to edit_collaborators_backoffice_compra_devolucao_path(@compra, documento_id: @rascunho.cod_documento_fiscal),
                alert: e.message
  rescue => e
    Rails.logger.error("[DevolucoesCompra#emitir] rascunho #{@rascunho&.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to edit_collaborators_backoffice_compra_devolucao_path(@compra, documento_id: @rascunho&.cod_documento_fiscal),
                alert: "Falha ao emitir devolução: #{e.message}"
  end

  # POST .../compras/:compra_id/devolucao/previsualizar
  # Gera o DANFE de PRE-VISUALIZACAO da devolucao (sem transmitir a SEFAZ),
  # usando os mesmos itens/CFOP/finalidade do formulario.
  # Via AJAX: responde o PDF (sucesso) ou JSON com erro (falha). O front so
  # abre a aba quando o PDF chega; em erro, mostra o alerta na propria tela.
  def previsualizar
    preview = montar_emissor.pre_visualizar(tipo_arquivo: 1)
    if preview.sucesso?
      send_data preview.conteudo, filename: "previsualizacao-devolucao-compra-#{@compra.cod_compra}.pdf",
                type: "application/pdf", disposition: "inline"
    else
      render json: { erro: "Não foi possível pré-visualizar: #{preview.erro}" }, status: :unprocessable_entity
    end
  rescue DevolucaoInvalida,
         Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    render json: { erro: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("[DevolucoesCompra#previsualizar] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    render json: { erro: "Falha ao pré-visualizar: #{e.message}" }, status: :unprocessable_entity
  end

  private

  # Monta o EmissorFiscal da devolucao a partir dos params do form (itens
  # editados, CFOP, natureza, finalidade). Retorna nil (apos redirecionar com
  # alerta) quando falta config ou nao ha itens. Usado por create e previsualizar.
  class DevolucaoInvalida < StandardError; end

  # Monta o EmissorFiscal da devolucao. Por padrao le os itens/cabecalho dos
  # PARAMS do form (fluxo new -> create/previsualizar). Quando chamado com
  # itens:/documento:/cabecalho (fluxo emitir rascunho), usa esses dados
  # persistidos em vez dos params, e reaproveita o DocumentoFiscal (documento:).
  def montar_emissor(itens: nil, documento: nil, operacao: nil, finalidade: nil,
                     chave: nil, transporte: nil, info_adicional: nil,
                     info_adicional_fisco: nil)
    config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
    raise DevolucaoInvalida, "Empresa sem configuração fiscal ativa." if config.nil? || !config.ativo?

    do_params = itens.nil? # modo "ler dos params do form"
    operacao ||= operacao_do_form

    if do_params
      extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
      itens = aplicar_edicoes(extractor.itens)
      chave = params[:chave_referencia].presence || extractor.chave_referencia
      transporte = transporte_param
      info_adicional = params[:info_adicional].to_s.strip.first(2000).presence
      info_adicional_fisco = params[:info_adicional_fisco].to_s.strip.first(2000).presence
    end

    raise DevolucaoInvalida, "Nenhum item para devolver." if itens.blank?

    finalidade = (finalidade.presence || params[:finalidade].presence || 4).to_i

    builder = Fiscal::DevolucaoCompraBuilder.new(
      @compra, config: config, itens: itens, chave_referencia: chave,
      natureza_operacao: params[:natureza_operacao].presence || operacao&.natureza_operacao,
      cfop: params[:cfop].presence, modelo: 55, finalidade: finalidade,
      operacao: operacao, # operacao da NF escolhida no topo (resolve CFOP/tributacao)
      transporte: transporte,
      info_adicional: info_adicional,
      info_adicional_fisco: info_adicional_fisco
    )

    origem = Fiscal::OrigemDevolucao.new(@compra.empresa)
    Fiscal::EmissorFiscal.new(
      origem, modelo: 55, operacao: operacao,
      cod_funcionario: current_collaborator.cod_funcionario,
      builder: builder, cod_compra: @compra.cod_compra, finalidade: finalidade,
      documento: documento
    )
  end

  # Converte um CFOP de entrada (1/2/3xxx) para saida (5/6/7xxx), para o
  # fallback quando o produto nao tem regra fiscal de devolucao.
  def cfop_convertido(cfop_entrada)
    c = cfop_entrada.to_s.gsub(/\D/, "")
    return nil if c.length < 4
    { "1" => "5", "2" => "6", "3" => "7" }.fetch(c[0], c[0]) + c[1..]
  end

  def set_compra
    @compra = Compra.find_by(cod_compra: params[:compra_id])
    redirect_to collaborators_backoffice_report_buy_path, alert: "Compra não encontrada." if @compra.nil?
  end

  # Localiza o RASCUNHO de devolucao a editar/emitir (edit, emitir). Exige
  # documento_id e valida: pertence a empresa, a esta compra e esta em
  # elaboracao (rascunho/erro/rejeitada). Documento autorizado nao reabre.
  EM_ELABORACAO = %w[rascunho erro rejeitada].freeze
  def set_rascunho
    return if @compra.nil? # set_compra ja redirecionou
    @rascunho = DocumentoFiscal
                .where(cod_empresa: @compra.cod_empresa, cod_compra: @compra.cod_compra)
                .find_by(cod_documento_fiscal: params[:documento_id])
    if @rascunho.nil?
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "Rascunho de devolução não encontrado." and return
    end
    unless EM_ELABORACAO.include?(@rascunho.status)
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "Só é possível editar/emitir devoluções em elaboração." and return
    end
  end

  # Variaveis compartilhadas por new e edit (seletores da view).
  def carregar_opcoes_view
    # Lista TODAS as operacoes ativas (saida e entrada). O usuario precisa poder
    # escolher no topo a MESMA operacao que esta cadastrada na regra do perfil.
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(nome: "Devolucao de compra")
    @finalidades = DocumentoFiscal::FINALIDADES
    # Perfis de SAIDA para o seletor por item (operacao + perfil resolvem o CFOP).
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)
  end

  # Operacao escolhida no form (topo), com fallback na de devolucao de compra.
  def operacao_do_form
    OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
      OperacaoFiscal.find_by(nome: "Devolucao de compra")
  end

  # Ultimo DocumentoFiscal de devolucao desta compra (qualquer status), para o
  # new decidir entre reaproveitar (rascunho/autorizada) ou criar. Pega o mais
  # recente (maior cod_documento_fiscal).
  def ultimo_documento_devolucao
    DocumentoFiscal
      .where(cod_empresa: @compra.cod_empresa, cod_compra: @compra.cod_compra)
      .order(cod_documento_fiscal: :desc)
      .first
  end

  # Rascunho desta compra a reaproveitar ao (re)salvar: o indicado por
  # documento_id (quando o form veio do edit) ou, na ausencia, nil (cria novo).
  # So reaproveita documentos em elaboracao desta empresa/compra.
  def rascunho_existente
    id = params[:documento_id].presence
    return nil if id.blank?
    DocumentoFiscal
      .where(cod_empresa: @compra.cod_empresa, cod_compra: @compra.cod_compra,
             status: EM_ELABORACAO)
      .find_by(cod_documento_fiscal: id)
  end

  # Ultimo rascunho (em elaboracao) desta compra, independente de documento_id.
  # Usado para nao criar uma segunda devolucao quando ja existe uma em aberto.
  def rascunho_em_elaboracao_da_compra
    DocumentoFiscal
      .where(cod_empresa: @compra.cod_empresa, cod_compra: @compra.cod_compra,
             status: EM_ELABORACAO)
      .order(cod_documento_fiscal: :desc)
      .first
  end

  # Atributos de cabecalho do rascunho de devolucao (operacao, finalidade,
  # natureza, observacoes, transporte, chave referenciada). O destinatario
  # (fornecedor) vem sempre da compra, entao nao se grava cod_pessoa_rascunho.
  def atributos_cabecalho_rascunho(operacao, finalidade, chave)
    {
      natureza_operacao:            params[:natureza_operacao].presence || operacao&.natureza_operacao,
      finalidade:                   finalidade,
      cod_operacao_fiscal_rascunho: operacao&.cod_operacao_fiscal,
      info_adicional:               params[:info_adicional].to_s.strip.first(2000).presence,
      info_adicional_fisco:         params[:info_adicional_fisco].to_s.strip.first(2000).presence,
      transporte:                   transporte_param,
      chave_referenciada:           (chave.to_s.gsub(/\D/, "").presence if chave.to_s.gsub(/\D/, "").length == 44)
    }
  end

  # Grava os itens de devolucao (ja com edicoes aplicadas por aplicar_edicoes)
  # como documento_fiscal_item. Campos basicos (produto/cor/qtd/valor/cfop/perfil)
  # vao nas colunas; o SNAPSHOT fiscal (imposto espelho + override + dados do
  # XML) vai em dados_devolucao (jsonb), para reabrir sem reler o XML.
  def gravar_itens_rascunho(documento, itens)
    itens.each_with_index do |it, idx|
      documento.itens.create!(
        cod_produto:           it[:cod_produto],
        cod_cor:               it[:cod_cor].presence,
        nome_produto:          it[:descricao].to_s.first(120).presence,
        quantidade:            it[:quantidade],
        valorunitario:         it[:valor_unitario],
        cod_perfil_tributario: it[:cod_perfil_tributario].presence,
        cfop:                  it[:cfop].to_s.gsub(/\D/, "").presence,
        ordem:                 idx,
        dados_devolucao:       snapshot_devolucao(it)
      )
    end
  end

  # Monta o snapshot fiscal (jsonb) de um item de devolucao para reabrir depois.
  # Guarda o espelho do XML, os overrides manuais e os campos do XML que nao tem
  # coluna propria (ncm, ean, unidade, origem, quantidade_original, descricao).
  def snapshot_devolucao(it)
    {
      "descricao"           => it[:descricao],
      "ncm"                 => it[:ncm],
      "ean"                 => it[:ean],
      "unidade"             => it[:unidade],
      "origem"              => it[:origem],
      "cfop_original"       => it[:cfop_original],
      "quantidade_original" => it[:quantidade_original].to_s,
      "imposto"             => stringify(it[:imposto]),
      "imposto_override"    => stringify(it[:imposto_override])
    }.compact
  end

  # Converte Hash (eventualmente com chaves symbol e BigDecimal) em algo
  # serializavel em jsonb de forma estavel (chaves string, numeros em string).
  def stringify(obj)
    case obj
    when Hash  then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    when Array then obj.map { |v| stringify(v) }
    when BigDecimal then obj.to_s("F")
    else obj
    end
  end

  # Reconstroi os itens de um rascunho no MESMO shape que o extractor produz,
  # para a view (new) reexibir a grade preenchida. Le o snapshot (dados_devolucao)
  # e cai nas colunas basicas para quantidade/valor/cfop/perfil.
  def itens_do_rascunho_para_view(documento)
    documento.itens.order(:ordem, :cod_documento_fiscal_item).map do |item|
      dd  = (item.dados_devolucao || {})
      imp = simbolizar_imposto(dd["imposto"])
      q_orig = dd["quantidade_original"].to_s.to_d
      {
        cod_produto:         item.cod_produto,
        cod_cor:             item.cod_cor,
        descricao:           dd["descricao"].presence || item.nome_produto,
        ncm:                 dd["ncm"],
        ean:                 dd["ean"],
        unidade:             dd["unidade"].presence || "UN",
        origem:              dd["origem"],
        cfop_original:       dd["cfop_original"],
        quantidade:          item.quantidade.to_d,
        quantidade_original: (q_orig.nonzero? || item.quantidade.to_d),
        valor_unitario:      item.valorunitario.to_d,
        valor_total:         item.valor_total.to_d,
        imposto:             imp,
        cod_perfil_tributario: item.cod_perfil_tributario,
        # CFOP salvo vira o "sugerido" (a view usa cfop_sugerido no input).
        cfop_sugerido:       item.cfop.presence,
        # Overrides manuais salvos: a view mostra o valor editado no campo visivel
        # (o hidden *_auto mantem o rateio do XML como baseline).
        imposto_override:    simbolizar_override(dd["imposto_override"])
      }
    end
  end

  # Reconstroi os itens de um rascunho no shape que o DevolucaoCompraBuilder
  # espera (para emitir SEM passar pelo form — emissao direta da lista). Repassa
  # o espelho do XML e o override ja salvos, sem reler o XML.
  def itens_do_rascunho_para_emissao(documento)
    documento.itens.order(:ordem, :cod_documento_fiscal_item).map do |item|
      dd  = (item.dados_devolucao || {})
      q_orig = dd["quantidade_original"].to_s.to_d
      {
        cod_produto:         item.cod_produto,
        cod_cor:             item.cod_cor,
        descricao:           dd["descricao"].presence || item.nome_produto,
        ncm:                 dd["ncm"],
        ean:                 dd["ean"],
        unidade:             dd["unidade"].presence || "UN",
        origem:              dd["origem"],
        cfop_original:       dd["cfop_original"],
        quantidade:          item.quantidade.to_d,
        quantidade_original: (q_orig.nonzero? || item.quantidade.to_d),
        valor_unitario:      item.valorunitario.to_d,
        valor_total:         item.valor_total.to_d,
        cfop:                item.cfop.presence,
        cod_perfil_tributario: item.cod_perfil_tributario,
        imposto:             simbolizar_imposto(dd["imposto"]),
        imposto_override:    simbolizar_override(dd["imposto_override"])
      }
    end
  end

  # Converte o bloco "imposto" salvo (jsonb, chaves string, valores string) de
  # volta ao shape que o builder consome: { icms: {cst:, base_calculo:, ...}, ...}
  # com chaves symbol e valores numericos (BigDecimal) onde faz sentido.
  def simbolizar_imposto(imp)
    return {} if imp.blank?
    imp.each_with_object({}) do |(grupo, campos), out|
      next if campos.blank?
      out[grupo.to_sym] = campos.each_with_object({}) do |(k, v), h|
        h[k.to_sym] = (k.to_s == "cst" ? v : to_d_or_keep(v))
      end
    end
  end

  # Override salvo -> chaves symbol, valores numericos (aceita "0" explicito).
  def simbolizar_override(ov)
    return nil if ov.blank?
    ov.each_with_object({}) { |(k, v), h| h[k.to_sym] = to_d_or_keep(v) }
  end

  def to_d_or_keep(v)
    return v if v.nil?
    s = v.to_s
    (s =~ /\A-?\d+(\.\d+)?\z/) ? s.to_d : v
  end

  # Valida a devolucao (fonte de verdade do painel de pendencias). Checa:
  #  - fornecedor (destinatario) com CPF/CNPJ valido e, sendo PJ, com IE
  #    (sem IE a SEFAZ trata como nao contribuinte -> rejeicao 696);
  #  - por item MARCADO: CFOP preenchido, quantidade > 0, valor unitario > 0;
  #  - ao menos um item marcado;
  #  - transporte: transportadora/volumes com modalidade "9" (incoerente).
  # Retorna { mensagens:, marcadores: { itens:{idx=>[campos]}, fornecedor:bool, transporte:bool } }.
  def validar_devolucao
    mensagens = []
    marc_itens = Hash.new { |h, k| h[k] = [] }
    marc_forn = false
    marc_transp = false

    # Fornecedor (destinatario da devolucao).
    forn = @compra.pessoa
    doc = forn&.cpf_cnpj.to_s.gsub(/\D/, "")
    if doc.blank?
      mensagens << "Fornecedor sem CPF/CNPJ cadastrado."
      marc_forn = true
    elsif !(CPF.valid?(doc) || CNPJ.valid?(doc))
      mensagens << "Fornecedor: CPF/CNPJ inválido (#{forn&.cpf_cnpj})."
      marc_forn = true
    elsif doc.length == 14 && forn.rg_ie.to_s.gsub(/\D/, "").blank?
      # PJ sem IE -> nao contribuinte -> rejeicao 696 na devolucao.
      mensagens << "Fornecedor PJ sem Inscrição Estadual (IE) no cadastro — necessária para a devolução."
      marc_forn = true
    end

    # Itens marcados (devolver = 1).
    brutos = params[:itens]
    brutos = brutos.values if brutos.is_a?(ActionController::Parameters)
    marcados = 0
    Array(brutos).each_with_index do |it, idx|
      h = it.respond_to?(:to_unsafe_h) ? it.to_unsafe_h : it.to_h
      next unless ActiveModel::Type::Boolean.new.cast(h["devolver"])
      marcados += 1
      nome = h["descricao"].to_s.first(40).presence || "item #{idx + 1}"
      qtd  = MoedaBr.parse(h["quantidade"]).to_d
      vl   = MoedaBr.parse(h["valor_unitario"]).to_d
      cfop = h["cfop"].to_s.gsub(/\D/, "")

      if cfop.blank?
        mensagens << "#{nome}: CFOP não resolvido (verifique perfil/operação/regra)."
        marc_itens[idx] << "cfop"
      end
      unless qtd > 0
        mensagens << "#{nome}: quantidade deve ser maior que zero."
        marc_itens[idx] << "quantidade"
      end
      unless vl > 0
        mensagens << "#{nome}: valor unitário deve ser maior que zero."
        marc_itens[idx] << "valor_unitario"
      end
    end
    mensagens << "Marque ao menos um item para devolver." if marcados.zero?

    # Transporte: transportadora/volumes com modalidade "9" (sem transporte).
    t = params[:transporte]
    if t.present?
      tp = t.respond_to?(:to_unsafe_h) ? t.to_unsafe_h : t.to_h
      modalidade = tp["modalidade_frete"].to_s
      tem_transportadora = tp["transportadora_cod_pessoa"].to_s.strip.present?
      tem_volumes = tp["possui_volumes"].to_s == "1" ||
                    %w[volume_qtd volume_especie volume_marca volume_numero peso_liquido peso_bruto].any? { |k| tp[k].to_s.strip.present? }
      if (tem_transportadora || tem_volumes) && (modalidade.blank? || modalidade == "9")
        mensagens << "Transporte: você informou transportadora/volumes, mas o frete está como \"Sem transporte (9)\". Selecione a modalidade do frete (0 a 4) ou remova os dados."
        marc_transp = true
      end
    end

    {
      mensagens: mensagens,
      marcadores: { itens: marc_itens.transform_values(&:uniq),
                    fornecedor: marc_forn, transporte: marc_transp }
    }
  end

  # Dados de transporte do form (mesmo formato/limpeza do editor de nota avulsa):
  # transportadora e uma Pessoa (busca), veiculo so com transportadora, volumes
  # so com o toggle. Retorna nil quando so ha modalidade "9" (sem transporte).
  def transporte_param
    t = params[:transporte]
    return nil if t.blank?
    t = t.permit(:modalidade_frete, :transportadora_cod_pessoa, :transportadora_nome,
                 :placa, :placa_uf, :rntc,
                 :possui_volumes, :volume_qtd, :volume_especie, :volume_marca,
                 :volume_numero, :peso_liquido, :peso_bruto).to_h

    if t["transportadora_cod_pessoa"].to_s.strip.blank?
      t.delete("transportadora_cod_pessoa"); t.delete("transportadora_nome")
      %w[placa placa_uf rntc].each { |k| t.delete(k) }
    end
    if t["possui_volumes"].to_s != "1"
      %w[possui_volumes volume_qtd volume_especie volume_marca volume_numero
         peso_liquido peso_bruto].each { |k| t.delete(k) }
    end
    t = t.reject { |_, v| v.to_s.strip.blank? }
    return nil if t.empty? || (t.keys == ["modalidade_frete"] && t["modalidade_frete"].to_s == "9")
    t
  end

  # Aplica as edicoes do form (quantidade/valor por item) sobre os itens
  # espelhados. Itens desmarcados (sem checkbox "devolver") sao removidos.
  def aplicar_edicoes(itens_base)
    editados = params[:itens]
    return itens_base if editados.blank?
    editados = editados.values if editados.is_a?(ActionController::Parameters)

    itens_base.each_with_index.filter_map do |it, i|
      ed = editados[i] || editados[i.to_s] || {}
      ed = ed.to_unsafe_h if ed.respond_to?(:to_unsafe_h)
      next unless ActiveModel::Type::Boolean.new.cast(ed["devolver"]) # so marcados

      # Overrides manuais de imposto (base/valor ICMS e valor IPI). So contam
      # como override quando o usuario ALTEROU o valor em relacao ao rateio
      # automatico (comparado ao campo *_auto escondido). Assim, mudar so a
      # quantidade NAO congela o imposto no valor pre-preenchido.
      override = {
        icms_base:     imposto_override(ed["icms_base"],     ed["icms_base_auto"]),
        icms_valor:    imposto_override(ed["icms_valor"],    ed["icms_valor_auto"]),
        icms_aliquota: imposto_override(ed["icms_aliquota"], ed["icms_aliquota_auto"]),
        ipi_valor:     imposto_override(ed["ipi_valor"],     ed["ipi_valor_auto"]),
        ipi_aliquota:  imposto_override(ed["ipi_aliquota"],  ed["ipi_aliquota_auto"])
      }.compact

      # Perfil escolhido na linha. Se o PRODUTO ainda nao tem perfil, grava o
      # escolhido como padrao do produto (fica salvo para as proximas vezes).
      cod_perfil = ed["cod_perfil_tributario"].presence
      aplicar_perfil_ao_produto(it[:cod_produto], cod_perfil) if cod_perfil

      it.merge(
        quantidade:       MoedaBr.parse(ed["quantidade"]).presence || it[:quantidade],
        valor_unitario:   MoedaBr.parse(ed["valor_unitario"]).presence || it[:valor_unitario],
        valor_total:      (MoedaBr.parse(ed["quantidade"]).to_d.nonzero? && MoedaBr.parse(ed["valor_unitario"]).to_d.nonzero?) ?
                            (MoedaBr.parse(ed["quantidade"]).to_d * MoedaBr.parse(ed["valor_unitario"]).to_d) : it[:valor_total],
        cfop:             ed["cfop"].to_s.gsub(/\D/, "").presence, # CFOP por item (sobrepoe o geral)
        cod_perfil_tributario: cod_perfil, # perfil escolhido na tela (prioridade sobre o do produto)
        imposto_override: override.presence
      )
    end
  end

  # Grava o perfil escolhido como padrao do produto, mas SO quando o produto
  # ainda nao tem perfil (nao sobrescreve um perfil ja definido).
  def aplicar_perfil_ao_produto(cod_produto, cod_perfil)
    produto = Produto.find_by(cod_produto: cod_produto)
    return if produto.nil? || produto.cod_perfil_tributario.present?
    produto.update_column(:cod_perfil_tributario, cod_perfil)
  rescue => e
    Rails.logger.error("[DevolucoesCompra#aplicar_perfil_ao_produto] #{e.class} - #{e.message}")
  end

  # Interpreta o campo de imposto editado em relacao ao valor automatico
  # pre-preenchido (campo *_auto). Regras:
  #   - vazio E o auto tinha valor  -> usuario APAGOU: zera (retorna 0);
  #   - vazio E o auto tambem vazio  -> nao mexeu: nil;
  #   - preenchido = auto            -> nao mexeu: nil (deixa o builder usar o XML);
  #   - preenchido != auto           -> override com o valor digitado.
  # Assim, apagar o campo tira o imposto (nao volta ao valor do XML).
  def imposto_override(valor, valor_auto)
    bruto = valor.to_s.strip
    auto  = MoedaBr.parse(valor_auto)

    if bruto.empty?
      return auto.present? ? 0 : nil   # apagou um campo que tinha valor -> zera
    end

    v = MoedaBr.parse(valor)
    return nil if v.nil?
    return v if auto.nil?
    (v.to_d.round(2) == auto.to_d.round(2)) ? nil : v
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
