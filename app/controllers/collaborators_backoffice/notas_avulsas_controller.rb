class CollaboratorsBackoffice::NotasAvulsasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_documento, only: [:show, :danfe, :cancelar, :destroy, :edit, :update, :emitir]

  MODELOS = [55, 65].freeze

  # Lista TODAS as notas fiscais da empresa (avulsas, de venda e de devolucao
  # de compra). Antes filtrava cod_venda: nil (so avulsas puras), o que escondia
  # os rascunhos/notas gerados a partir de venda. A coluna "Origem" distingue.
  def index
    @documentos = DocumentoFiscal
                  .where(cod_empresa: current_collaborator.cod_empresa)
                  .includes(:venda) # evita N+1 ao exibir cod_vendaempresa
                  .order(cod_documento_fiscal: :desc)
                  .limit(100)
  end

  # Formulario de emissao avulsa. modelo = 55 (NF-e, default) ou 65 (NFC-e).
  def new
    @modelo = modelo_param
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(nome: "Venda (NF-e)") || OperacaoFiscal.find_by(nome: "Venda (NF-c)")
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)
    @finalidades = DocumentoFiscal::FINALIDADES
    # Itens re-exibidos quando o create falha (preserva o que o usuario digitou).
    @itens_preenchidos = @itens_preenchidos || []
    @pagamentos_sel = @pagamentos_sel || []
    @transporte_sel = @transporte_sel || {}
    @cobranca_sel = @cobranca_sel || {}
    @fatura_numero_base = @fatura_numero_base # nil no new puro (avulsa)
  end

  # GET .../notas_avulsas/resolver_cfop?cod_produto=&cod_operacao_fiscal=&cod_perfil_tributario=
  # Resolve o CFOP de um item pela regra (perfil + operacao do topo), com destino
  # = UF do destinatario informado (ou UF da empresa). Sem regra, CFOP em branco.
  def resolver_cfop
    empresa  = current_collaborator.empresa
    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal])
    produto  = Produto.find_by(cod_produto: params[:cod_produto])
    # Fiscal do produto POR EMPRESA (com fallback no produto global).
    fiscal   = FiscalProduto.para(current_collaborator.cod_empresa, params[:cod_produto])
    perfil_escolhido = PerfilTributario.find_by(cod_perfil_tributario: params[:cod_perfil_tributario])

    # "Aprendizado" do perfil: se o produto AINDA NAO tem perfil (nem na
    # fiscal_produto nem no fallback) e o usuario escolheu um na tela, grava
    # esse perfil na fiscal_produto da empresa — so quando esta vazio (nao
    # sobrescreve perfil ja definido). Facilita nao ter que reescolher depois.
    if perfil_escolhido && fiscal.cod_perfil_tributario.blank? && produto
      aprender_perfil_fiscal_produto(produto.cod_produto, perfil_escolhido.cod_perfil_tributario)
      fiscal = FiscalProduto.para(current_collaborator.cod_empresa, params[:cod_produto]) # recarrega
    end

    # Perfil explicito (escolhido na tela) tem prioridade; senao, o da fiscal_produto.
    perfil   = perfil_escolhido || fiscal.perfil_tributario
    destinatario = Pessoa.find_by(cod_pessoa: params[:cod_pessoa])

    # tipo_cliente segue a mesma logica da venda: sem destinatario (ou PF) =
    # consumidor_final; PJ = contribuinte. Fixar "contribuinte" fazia a regra de
    # Venda (consumidor_final) nao casar e o CFOP vir vazio.
    tipo_cliente = if destinatario&.pessoa_juridica? then "contribuinte" else "consumidor_final" end

    cfop = nil
    if operacao && (perfil || produto)
      cfop = Fiscal::CfopResolver.new(empresa: empresa, destino_uf: destinatario&.uf,
                                      tipo_cliente: tipo_cliente)
                                 .cfop(produto, operacao, perfil: perfil)
    end
    render json: {
      cfop:   cfop,
      origem: cfop.present? ? "regra" : "sem_regra",
      # Devolve o perfil da fiscal_produto (empresa) p/ o front pre-selecionar.
      cod_perfil_tributario: fiscal.cod_perfil_tributario
    }
  rescue => e
    Rails.logger.error("[NotasAvulsas#resolver_cfop] #{e.class} - #{e.message}")
    render json: { cfop: nil, origem: "erro" }
  end

  # Emite a NF avulsa a partir dos itens (e destinatario, se 55).
  def create
    @modelo = modelo_param
    empresa = current_collaborator.empresa
    cliente = resolver_cliente
    itens   = itens_param

    # Validacoes: em erro, RE-EXIBE o form com os dados preenchidos (sem redirect,
    # que recarregava o new vazio e apagava tudo que o usuario digitou).
    if @modelo == 55 && cliente.nil?
      return reexibir_form("NF-e (55) exige um destinatário. Informe o cliente.")
    end
    if itens.empty?
      return reexibir_form("Informe ao menos um produto.")
    end

    operacao = operacao_escolhida

    avulso = montar_avulso(empresa: empresa, cliente: cliente, itens: itens, cab: cabecalho_param)
    documento = Fiscal::EmissorFiscal.new(avulso, modelo: @modelo,
                                          operacao: operacao,
                                          finalidade: params[:finalidade],
                                          cod_funcionario: current_collaborator.cod_funcionario).emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_notas_avulsa_path(documento),
                  notice: "NF autorizada. Chave: #{documento.chave_acesso}"
    else
      reexibir_form("NF #{documento.status}: #{documento.mensagem_sefaz}")
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    reexibir_form(e.message)
  rescue => e
    Rails.logger.error("[NotasAvulsas#create] #{e.class} - #{e.message}")
    reexibir_form("Falha ao emitir: #{e.message}")
  end

  def show
    # Notas autorizadas: itens vivem no XML (resumo_do_xml). Rascunhos: itens
    # persistidos em documento_fiscal_item (mostramos esses se existirem).
    @resumo = resumo_do_xml(@documento)
  end

  # POST .../notas_avulsas/salvar_rascunho
  # Salva a nota como RASCUNHO editavel (sem emitir, sem SEFAZ). Cria o
  # DocumentoFiscal com status rascunho (cod_venda nil = avulsa) e grava os
  # itens em documento_fiscal_item. Permite montar a nota, conferir e emitir depois.
  def salvar_rascunho
    @modelo = modelo_param
    cliente = resolver_cliente
    itens   = itens_param

    return reexibir_form("Informe ao menos um produto para salvar.") if itens.empty?

    operacao = operacao_escolhida
    documento = nil
    ActiveRecord::Base.transaction do
      documento = DocumentoFiscal.create!({
        cod_empresa:       current_collaborator.cod_empresa,
        cod_venda:         nil,
        modelo:            @modelo,
        natureza_operacao: operacao&.natureza_operacao,
        finalidade:        (params[:finalidade].presence || 1).to_i,
        ambiente:          FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)&.ambiente || "homologacao",
        status:            "rascunho",
        cod_funcionario:   current_collaborator.cod_funcionario,
        cod_pessoa_rascunho: cliente&.cod_pessoa,
        cod_operacao_fiscal_rascunho: operacao&.cod_operacao_fiscal
      }.merge(atributos_cabecalho_documento))
      gravar_itens_rascunho(documento, itens)
    end

    redirect_to collaborators_backoffice_notas_avulsas_path,
                notice: "Nota salva como rascunho (##{documento.cod_documento_fiscal}). Edite e emita quando quiser."
  rescue => e
    Rails.logger.error("[NotasAvulsas#salvar_rascunho] #{e.class} - #{e.message}")
    reexibir_form("Falha ao salvar o rascunho: #{e.message}")
  end

  # POST .../notas_avulsas/gerar_de_venda?cod_venda=
  # Cria (ou REAPROVEITA, enquanto for rascunho) um rascunho de NF a partir de
  # uma VENDA: copia itens e destinatario da venda para o editor de nota, com
  # cod_venda preenchido (NF de venda, nao avulsa). Abre o editor (edit).
  def gerar_de_venda
    venda = Venda.where(cod_empresa: current_collaborator.cod_empresa)
                 .find_by(cod_venda: params[:cod_venda])
    if venda.nil?
      redirect_to collaborators_backoffice_report_sales_path,
                  alert: "Venda não encontrada." and return
    end

    # Se a venda ja tem NF autorizada (55 ou 65), nao gera outro rascunho:
    # abre a NF ja emitida para visualizacao.
    nf = venda.nfe_autorizada
    if nf
      redirect_to collaborators_backoffice_notas_avulsa_path(nf),
                  notice: "Esta venda já tem NF autorizada (##{nf.cod_documento_fiscal})." and return
    end

    # Ja existe rascunho desta venda? Entao APENAS ABRE o rascunho salvo, sem
    # sobrescrever — preserva as edicoes feitas no editor (modelo, destinatario,
    # itens, CFOP). So montamos a partir da venda quando criamos um rascunho novo.
    existente = DocumentoFiscal.where(cod_empresa: current_collaborator.cod_empresa,
                                      cod_venda: venda.cod_venda, status: "rascunho")
                               .order(cod_documento_fiscal: :desc).first
    if existente
      redirect_to edit_collaborators_backoffice_notas_avulsa_path(existente),
                  notice: "Rascunho da NF da venda ##{venda.cod_vendaempresa || venda.cod_venda} reaberto. Confira e emita." and return
    end

    @modelo = 55 # NF de venda = NF-e modelo 55
    operacao = OperacaoFiscal.find_by(nome: "Venda (NF-e)") || operacao_escolhida
    itens = itens_da_venda(venda)
    if itens.empty?
      redirect_to collaborators_backoffice_report_sales_path,
                  alert: "A venda não tem itens para gerar a NF." and return
    end

    documento = nil
    ActiveRecord::Base.transaction do
      documento = DocumentoFiscal.create!(
        cod_empresa:       current_collaborator.cod_empresa,
        cod_venda:         venda.cod_venda,
        modelo:            @modelo,
        natureza_operacao: operacao&.natureza_operacao,
        finalidade:        1,
        ambiente:          FiscalConfig.find_by(cod_empresa: current_collaborator.cod_empresa)&.ambiente || "homologacao",
        status:            "rascunho",
        cod_funcionario:   current_collaborator.cod_funcionario,
        cod_pessoa_rascunho: venda.cod_pessoa,
        cod_operacao_fiscal_rascunho: operacao&.cod_operacao_fiscal,
        # Pre-preenche as parcelas (duplicatas) a partir das contas da venda.
        # Fica salvo, mas so VAI ao cliente se a forma de pagamento na NF for a
        # prazo (≠ 99/90). No default (99) a duplicata nao e enviada.
        cobranca:          cobranca_da_venda(venda)
      )
      gravar_itens_rascunho(documento, itens)
    end

    redirect_to edit_collaborators_backoffice_notas_avulsa_path(documento),
                notice: "Rascunho da NF gerado a partir da venda ##{venda.cod_vendaempresa || venda.cod_venda}. Confira e emita."
  rescue => e
    Rails.logger.error("[NotasAvulsas#gerar_de_venda] venda #{params[:cod_venda]}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_report_sales_path,
                alert: "Falha ao gerar a NF da venda: #{e.message}"
  end

  # POST .../notas_avulsas/:id/emitir
  # Emite uma NOTA EM ELABORACAO (rascunho ja salvo): monta o avulso a partir
  # dos itens PERSISTIDOS e reaproveita o cabecalho rascunho (nao cria outro).
  def emitir
    unless em_elaboracao?(@documento)
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "Só é possível emitir notas em elaboração." and return
    end
    emitir_documento_persistido(@documento)
  end

  # Edita um rascunho: reexibe o form preenchido a partir dos itens persistidos.
  def edit
    unless em_elaboracao?(@documento)
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "Só é possível editar notas em elaboração." and return
    end
    @modelo = @documento.modelo
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(cod_operacao_fiscal: @documento.cod_operacao_fiscal_rascunho) ||
                       OperacaoFiscal.find_by(nome: "Venda (NF-e)")
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)
    @finalidades = DocumentoFiscal::FINALIDADES
    @finalidade_sel = @documento.finalidade
    @cod_pessoa_sel = @documento.cod_pessoa_rascunho
    # Nome do destinatario para o form reexibir o campo visivel (nao so o hidden).
    @nome_pessoa_sel = Pessoa.find_by(cod_pessoa: @cod_pessoa_sel)&.nome if @cod_pessoa_sel.present?
    # Cabecalho fiscal (observacoes, pagamentos, transporte, NF ref) p/ reexibir.
    @info_adicional_sel       = @documento.info_adicional
    @info_adicional_fisco_sel = @documento.info_adicional_fisco
    @pagamentos_sel           = Array(@documento.pagamentos)
    @transporte_sel           = @documento.transporte || {}
    @cobranca_sel             = @documento.cobranca || {}
    @consumidor_final_sel     = @documento.consumidor_final
    @chave_referenciada_sel   = @documento.chave_referenciada
    # Numero-base da fatura: da cobranca salva; senao o cod_vendaempresa da venda
    # vinculada (NF de venda). Usado pelo JS ao (re)gerar parcelas, para numerar
    # as duplicatas como <base>-1..n em vez de um numero generico.
    @fatura_numero_base = @cobranca_sel.dig("fatura", "numero").presence ||
                          numero_base_da_venda(@documento.cod_venda)
    @itens_preenchidos = itens_do_rascunho(@documento)
    render :new
  end

  # Atualiza um rascunho (regrava itens e cabecalho).
  def update
    unless em_elaboracao?(@documento)
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "Só é possível editar notas em elaboração." and return
    end
    @modelo = modelo_param
    cliente = resolver_cliente
    itens   = itens_param
    operacao = operacao_escolhida

    return reexibir_form("Informe ao menos um produto.") if itens.empty?

    ActiveRecord::Base.transaction do
      @documento.update!({
        modelo:            @modelo,
        natureza_operacao: operacao&.natureza_operacao,
        finalidade:        (params[:finalidade].presence || 1).to_i,
        cod_pessoa_rascunho: cliente&.cod_pessoa,
        cod_operacao_fiscal_rascunho: operacao&.cod_operacao_fiscal
      }.merge(atributos_cabecalho_documento))
      @documento.itens.delete_all
      gravar_itens_rascunho(@documento, itens)
    end

    # "Salvar e emitir" num clique: quando o form pede emitir_apos, segue direto
    # para a emissao usando o que acabou de ser salvo (sem exigir 2 botoes).
    if params[:emitir_apos].present?
      @documento.reload
      return emitir_documento_persistido(@documento)
    end

    redirect_to collaborators_backoffice_notas_avulsas_path,
                notice: "Rascunho ##{@documento.cod_documento_fiscal} atualizado."
  rescue => e
    Rails.logger.error("[NotasAvulsas#update] #{e.class} - #{e.message}")
    reexibir_form("Falha ao atualizar o rascunho: #{e.message}")
  end

  # POST /collaborators_backoffice/notas_avulsas/validar
  # Valida o estado atual do formulario (itens + destinatario + modelo) e
  # devolve a lista COMPLETA de pendencias (dados basicos, CFOP, CPF/CNPJ,
  # estoque fiscal consolidado). O front chama este endpoint e exibe tudo no
  # painel, mantendo o backend como fonte unica de verdade.
  def validar
    modelo = modelo_param
    cliente = resolver_cliente
    itens   = itens_param
    res = validar_detalhado(modelo: modelo, cod_pessoa: cliente&.cod_pessoa, itens: itens,
                            pagamentos: pagamentos_param, transporte: transporte_param,
                            cobranca: cobranca_param)
    render json: { pendencias: res[:mensagens], marcadores: res[:marcadores],
                   ok: res[:mensagens].empty? }
  rescue => e
    Rails.logger.error("[NotasAvulsas#validar] #{e.class} - #{e.message}")
    render json: { pendencias: ["Falha ao validar: #{e.message}"], marcadores: {}, ok: false }
  end

  # POST /collaborators_backoffice/notas_avulsas/previsualizar
  # Gera o DANFE/DANFCE de PRE-VISUALIZACAO (sem transmitir a SEFAZ) a partir
  # dos itens/destinatario do formulario, usando a operacao/finalidade escolhidas.
  def previsualizar
    @modelo = modelo_param
    empresa = current_collaborator.empresa
    cliente = resolver_cliente
    itens   = itens_param

    if itens.empty?
      render json: { erro: "Informe ao menos um produto para pré-visualizar." },
             status: :unprocessable_entity
      return
    end

    operacao = operacao_escolhida
    avulso  = montar_avulso(empresa: empresa, cliente: cliente, itens: itens, cab: cabecalho_param)
    preview = Fiscal::EmissorFiscal.new(avulso, modelo: @modelo, operacao: operacao,
                                        finalidade: params[:finalidade],
                                        cod_funcionario: current_collaborator.cod_funcionario)
                                   .pre_visualizar(tipo_arquivo: 1)

    if preview.sucesso?
      # NFC-e (65) devolve o DANFCE em HTML; NF-e (55) em PDF. Serve com o
      # Content-Type real detectado para o navegador renderizar corretamente.
      send_data preview.conteudo,
                filename: "previsualizacao-avulsa-#{@modelo}.#{preview.extensao}",
                type: preview.content_type, disposition: "inline"
    else
      render json: { erro: "Não foi possível pré-visualizar: #{preview.erro}" },
             status: :unprocessable_entity
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    render json: { erro: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("[NotasAvulsas#previsualizar] #{e.class} - #{e.message}")
    render json: { erro: "Falha ao pré-visualizar: #{e.message}" }, status: :unprocessable_entity
  end

  # PDF do DANFE (quando autorizada).
  def danfe
    if @documento.danfe_base64.blank?
      redirect_to collaborators_backoffice_notas_avulsa_path(@documento), alert: "DANFE indisponível."
      return
    end
    conteudo = Base64.decode64(@documento.danfe_base64)
    # NFC-e (modelo 65) tem o DANFCE em HTML; NF-e 55 em PDF. Detecta o formato
    # real pelos primeiros bytes e serve com o Content-Type certo (senao o
    # navegador tenta abrir HTML como PDF e falha).
    tipo, ext = danfe_tipo_extensao(conteudo)
    # no-store: o navegador nao reusa resposta antiga quando o Content-Type
    # muda (NFC-e 65 = HTML, NF-e 55 = PDF), evitando aba em branco por cache.
    response.headers["Cache-Control"] = "no-store"
    send_data conteudo,
              filename: "danfe-avulsa-#{@documento.cod_documento_fiscal}.#{ext}",
              type: tipo, disposition: "inline"
  end

  # Cancela a NF avulsa autorizada.
  def cancelar
    @documento.cancelar!(justificativa: params[:justificativa].to_s,
                         cod_funcionario: current_collaborator.cod_funcionario)
    redirect_to collaborators_backoffice_notas_avulsas_path, notice: "NF cancelada."
  rescue ArgumentError => e
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: e.message
  rescue NotImplementedError
    redirect_to collaborators_backoffice_notas_avulsas_path,
                alert: "Cancelamento ainda não implementado para este provedor."
  rescue => e
    Rails.logger.error("[NotasAvulsas#cancelar] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: "Falha ao cancelar: #{e.message}"
  end

  # Exclui uma nota avulsa que NAO foi autorizada (erro/rejeitada/rascunho/
  # enviada). Documento autorizado ou cancelado tem valor fiscal e NAO pode ser
  # apagado (precisa ser cancelado na SEFAZ, nao excluido). Serve para limpar
  # tentativas que falharam (ex. dados fiscais incompletos), que nao viraram NF.
  def destroy
    if @documento.autorizada? || @documento.cancelada?
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "Não é possível excluir uma nota #{@documento.status}. Documentos com valor fiscal devem ser cancelados, não excluídos."
      return
    end

    @documento.destroy
    redirect_to collaborators_backoffice_notas_avulsas_path, notice: "Nota (#{@documento.status}) excluída."
  rescue => e
    Rails.logger.error("[NotasAvulsas#destroy] doc #{@documento&.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: "Falha ao excluir: #{e.message}"
  end

  # Cores de um produto (JSON) para o select de cor no form. Traz tambem a
  # qtdfiscal (estoque FISCAL) e a quantidade (estoque fisico) por cor, para o
  # usuario ver o saldo fiscal disponivel antes de emitir (a NF baixa qtdfiscal).
  def cores_produto
    cores = Core.select("cores.nmcor, cores.cod_cor, empresaproduto.valorvenda, " \
                        "empresaproduto.qtdfiscal, empresaproduto.quantidade")
                .joins(:empresaprodutos)
                .where("empresaproduto.cod_produto = ? and empresaproduto.cod_empresa = ?",
                       params[:cod_produto], current_collaborator.cod_empresa)
                .order(:nmcor, :cod_cor)
    render json: cores.map { |c|
      {
        cod_cor:    c.cod_cor,
        nmcor:      c.nmcor,
        valorvenda: c.valorvenda,
        qtdfiscal:  c.qtdfiscal.to_f,
        quantidade: c.quantidade.to_f
      }
    }
  end

  private

  def set_documento
    # Atende tanto notas avulsas puras (cod_venda nil) quanto RASCUNHOS de NF
    # de venda (cod_venda preenchido) — ambos usam o mesmo editor. Filtra so
    # pela empresa logada (isolamento), o status e validado em cada action.
    @documento = DocumentoFiscal.where(cod_empresa: current_collaborator.cod_empresa)
                                .find(params[:id])
  end

  # Nota em elaboracao = ainda editavel/emissivel pelo editor:
  #  - "rascunho": nunca transmitida.
  #  - "erro": falha de validacao local antes de transmitir.
  #  - "rejeitada": a SEFAZ recusou (ex.: IE invalida, dado errado) — NAO tem
  #    valor fiscal; o usuario corrige o cadastro/dados e reenvia o MESMO doc.
  # Nao inclui enviada/autorizada/cancelada (ja tem andamento/valor fiscal).
  EM_ELABORACAO = %w[rascunho erro rejeitada].freeze
  def em_elaboracao?(documento)
    EM_ELABORACAO.include?(documento.status)
  end

  # Compat: retorna so a LISTA DE MENSAGENS (usado na emissao). Internamente
  # delega para validar_detalhado, que tambem devolve os marcadores de campo.
  def validar_pendencias(modelo:, cod_pessoa:, itens:, pagamentos: nil, transporte: nil, cobranca: nil)
    validar_detalhado(modelo: modelo, cod_pessoa: cod_pessoa, itens: itens,
                      pagamentos: pagamentos, transporte: transporte, cobranca: cobranca)[:mensagens]
  end

  # Valida pendencias de EMISSAO no backend (fonte de verdade; o front chama via
  # endpoint validar). Por item exige cor, quantidade>0, valor>0, CFOP; checa
  # CPF/CNPJ do destinatario; e o estoque fiscal CONSOLIDADO por produto
  # (fiscal_produto.qtd_fiscal), somando as cores do mesmo produto na nota.
  #
  # Retorna { mensagens: [...], marcadores: { itens: { idx => [campos] },
  # destinatario: bool } } — os marcadores permitem ao front pintar de vermelho
  # os campos exatos com problema. campos: "cor","quantidade","valor","cfop".
  # NAO valida NCM/CSOSN (o EmissorFiscal cuida e lanca DadosFiscaisIncompletos).
  def validar_detalhado(modelo:, cod_pessoa:, itens:, pagamentos: nil, transporte: nil, cobranca: nil)
    mensagens = []
    marc_itens = Hash.new { |h, k| h[k] = [] }
    marc_dest = false

    # CPF/CNPJ do destinatario (quando informado): bloqueia documento invalido.
    if cod_pessoa.present?
      pessoa = Pessoa.find_by(cod_pessoa: cod_pessoa)
      doc = pessoa&.cpf_cnpj.to_s.gsub(/\D/, "")
      if doc.blank?
        mensagens << "Destinatário (#{pessoa&.nome}) sem CPF/CNPJ cadastrado."
        marc_dest = true
      elsif !(CPF.valid?(doc) || CNPJ.valid?(doc))
        mensagens << "Destinatário (#{pessoa&.nome}): CPF/CNPJ inválido (#{pessoa&.cpf_cnpj})."
        marc_dest = true
      end
    end

    # NF-e 55 exige destinatario.
    if modelo.to_i == 55 && cod_pessoa.blank?
      mensagens << "NF-e (55) exige um destinatário."
      marc_dest = true
    end

    com_produto = 0
    qtd_por_produto = Hash.new { |h, k| h[k] = BigDecimal("0") }
    # idx (posicao na lista) de cada linha por produto, p/ marcar o campo qtd
    # das linhas envolvidas quando o estoque consolidado estourar.
    idxs_por_produto = Hash.new { |h, k| h[k] = [] }

    itens.each_with_index do |it, idx|
      next if it[:cod_produto].blank?
      com_produto += 1
      prod = Produto.find_by(cod_produto: it[:cod_produto])
      nome = prod&.nome.presence || "produto #{it[:cod_produto]}"
      qtd  = it[:quantidade].to_d
      vl   = it[:valorunitario].to_d
      cfop = it[:cfop].to_s.gsub(/\D/, "")

      if it[:cod_cor].blank?
        mensagens << "#{nome}: selecione a cor."
        marc_itens[idx] << "cor"
      end
      unless qtd > 0
        mensagens << "#{nome}: quantidade deve ser maior que zero."
        marc_itens[idx] << "quantidade"
      end
      unless vl > 0
        mensagens << "#{nome}: valor unitário deve ser maior que zero."
        marc_itens[idx] << "valor"
      end
      if cfop.blank?
        mensagens << "#{nome}: CFOP não resolvido (verifique perfil/operação/regra)."
        marc_itens[idx] << "cfop"
      end

      if qtd > 0
        qtd_por_produto[it[:cod_produto]] += qtd
        idxs_por_produto[it[:cod_produto]] << idx
      end
    end

    mensagens << "Adicione ao menos um produto." if com_produto.zero?

    # Pagamentos (opcional): quando o usuario lanca pagamentos, a SOMA precisa
    # bater com o total da nota (senao a SEFAZ rejeita). Sem pagamentos lancados,
    # o builder usa o padrao (1 pagamento = total) e nada e validado aqui.
    pags = Array(pagamentos)
    if pags.any?
      total_nota = itens.sum { |it| it[:quantidade].to_d * it[:valorunitario].to_d }
      soma_pag = pags.sum { |p| (p["valor"] || p[:valor]).to_d }
      if (soma_pag - total_nota).abs >= BigDecimal("0.01")
        mensagens << "Pagamentos (#{MoedaBr.format(soma_pag)}) não batem com o total da nota (#{MoedaBr.format(total_nota)})."
      end
    end

    # Duplicatas (cobranca): quando ha parcelas, a SOMA delas deve bater com o
    # total da nota (a SEFAZ valida). So checa quando ha parcelas informadas.
    parcelas = cobranca.is_a?(Hash) ? Array(cobranca["parcelas"]) : []
    if parcelas.any?
      total_nota = itens.sum { |it| it[:quantidade].to_d * it[:valorunitario].to_d }
      soma_parc = parcelas.sum { |p| (p["valor"] || p[:valor]).to_d }
      if (soma_parc - total_nota).abs >= BigDecimal("0.01")
        mensagens << "Duplicatas (#{MoedaBr.format(soma_parc)}) não batem com o total da nota (#{MoedaBr.format(total_nota)})."
      end
    end

    # Transporte: modalidade "9" (sem transporte) e INCOMPATIVEL com informar
    # transportadora/volumes (a SEFAZ nao aceita e esses dados sao descartados).
    # Se o colaborador preencheu transporte mas deixou a modalidade em 9, obriga
    # a resolver: trocar a modalidade (0-4) OU remover os dados do transporte.
    t = transporte.is_a?(Hash) ? transporte : {}
    if t.present?
      modalidade = t["modalidade_frete"].to_s
      tem_transportadora = t["transportadora_cod_pessoa"].to_s.strip.present?
      tem_volumes = t["possui_volumes"].to_s == "1" ||
                    %w[volume_qtd volume_especie volume_marca volume_numero
                       peso_liquido peso_bruto].any? { |k| t[k].to_s.strip.present? }
      if (tem_transportadora || tem_volumes) && (modalidade.blank? || modalidade == "9")
        mensagens << "Transporte: você informou transportadora/volumes, mas o frete está como \"Sem transporte (9)\". Selecione a modalidade do frete (0 a 4) ou remova os dados do transporte."
      end
    end

    # Estoque fiscal CONSOLIDADO por produto (fiscal_produto.qtd_fiscal).
    qtd_por_produto.each do |cod_produto, qtd_total|
      fp = FiscalProduto.para(current_collaborator.cod_empresa, cod_produto)
      saldo = fp.qtd_fiscal.to_d
      next if qtd_total <= saldo

      prod = Produto.find_by(cod_produto: cod_produto)
      nome = prod&.nome.presence || "produto #{cod_produto}"
      mensagens << "#{nome}: estoque fiscal insuficiente (disponível #{MoedaBr.format(saldo)}, pedido #{MoedaBr.format(qtd_total)})."
      idxs_por_produto[cod_produto].each { |i| marc_itens[i] << "quantidade" }
    end

    {
      mensagens: mensagens,
      marcadores: {
        itens: marc_itens.transform_values(&:uniq),
        destinatario: marc_dest
      }
    }
  end

  # Emite um documento JA PERSISTIDO (rascunho/erro): monta o avulso a partir
  # dos itens/destinatario salvos e reaproveita o cabecalho (nao cria outro).
  # Usado por emitir (botao) e por update quando o form pede "salvar e emitir".
  def emitir_documento_persistido(documento)
    empresa  = current_collaborator.empresa
    cliente  = documento.cod_pessoa_rascunho.present? ? Pessoa.find_by(cod_pessoa: documento.cod_pessoa_rascunho) : nil
    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: documento.cod_operacao_fiscal_rascunho) ||
               OperacaoFiscal.find_by(nome: "Venda (NF-e)")
    itens    = itens_para_avulso(documento)

    if documento.modelo == 55 && cliente.nil?
      redirect_to edit_collaborators_backoffice_notas_avulsa_path(documento),
                  alert: "NF-e (55) exige um destinatário." and return
    end
    if itens.empty?
      redirect_to edit_collaborators_backoffice_notas_avulsa_path(documento),
                  alert: "A nota não tem itens." and return
    end

    # Revalidacao no BACKEND (nao depende so do JS): dados basicos + CPF/CNPJ +
    # estoque fiscal consolidado. Se houver pendencia, NAO emite; mantem o
    # rascunho para corrigir.
    pendencias = validar_pendencias(modelo: documento.modelo,
                                    cod_pessoa: documento.cod_pessoa_rascunho, itens: itens,
                                    pagamentos: documento.pagamentos,
                                    transporte: documento.transporte,
                                    cobranca: documento.cobranca)
    if pendencias.any?
      redirect_to edit_collaborators_backoffice_notas_avulsa_path(documento),
                  alert: "Não é possível emitir. #{pendencias.join(' | ')}" and return
    end

    avulso = montar_avulso(empresa: empresa, cliente: cliente, itens: itens,
                           cab: cabecalho_do_documento(documento))
    emitido = Fiscal::EmissorFiscal.new(avulso, modelo: documento.modelo,
                                        operacao: operacao,
                                        finalidade: documento.finalidade,
                                        cod_funcionario: current_collaborator.cod_funcionario,
                                        documento: documento).emitir

    if emitido.autorizada?
      redirect_to collaborators_backoffice_notas_avulsa_path(emitido),
                  notice: "NF autorizada. Chave: #{emitido.chave_acesso}"
    else
      redirect_to edit_collaborators_backoffice_notas_avulsa_path(emitido),
                  alert: "NF #{emitido.status}: #{emitido.mensagem_sefaz}"
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao,
         Fiscal::EmissorFiscal::JaAutorizada => e
    redirect_to edit_collaborators_backoffice_notas_avulsa_path(documento), alert: e.message
  rescue => e
    Rails.logger.error("[NotasAvulsas#emitir_documento_persistido] doc #{documento&.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to edit_collaborators_backoffice_notas_avulsa_path(documento), alert: "Falha ao emitir: #{e.message}"
  end

  # Le o XML autorizado (xml_base64) e devolve um Hash com os dados gerais e os
  # itens da nota, para exibir na tela show. nil quando nao ha XML.
  def resumo_do_xml(documento)
    b64 = documento.xml_base64.presence
    return nil if b64.blank?

    xml = Base64.decode64(b64)
    doc = Nokogiri::XML(xml)
    g = ->(xp) { doc.at_xpath(xp)&.text }

    dest_nome = g.call('//*[local-name()="dest"]/*[local-name()="xNome"]')

    itens = doc.xpath('//*[local-name()="det"]').map do |det|
      prod = det.at_xpath('.//*[local-name()="prod"]')
      pg = ->(xp) { prod&.at_xpath(xp)&.text }
      {
        n:      det["nItem"],
        codigo: pg.call('.//*[local-name()="cProd"]'),
        nome:   pg.call('.//*[local-name()="xProd"]'),
        ncm:    pg.call('.//*[local-name()="NCM"]'),
        cfop:   pg.call('.//*[local-name()="CFOP"]'),
        qtd:    pg.call('.//*[local-name()="qCom"]').to_f,
        vun:    pg.call('.//*[local-name()="vUnCom"]').to_f,
        vprod:  pg.call('.//*[local-name()="vProd"]').to_f
      }
    end

    {
      numero:    g.call('//*[local-name()="ide"]/*[local-name()="nNF"]'),
      serie:     g.call('//*[local-name()="ide"]/*[local-name()="serie"]'),
      natureza:  g.call('//*[local-name()="ide"]/*[local-name()="natOp"]'),
      emitida_em: g.call('//*[local-name()="ide"]/*[local-name()="dhEmi"]'),
      destinatario: dest_nome,
      total:     g.call('//*[local-name()="ICMSTot"]/*[local-name()="vNF"]').to_f,
      itens:     itens
    }
  rescue => e
    Rails.logger.error("[NotasAvulsas#resumo_do_xml] doc #{documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    nil
  end

  # Detecta o Content-Type do arquivo do DANFE/DANFCE pelos primeiros bytes.
  # PDF (NF-e 55) comeca com "%PDF"; DANFCE (NFC-e 65) e HTML.
  def danfe_tipo_extensao(conteudo)
    amostra = conteudo.to_s[0, 64].to_s
    if amostra.start_with?("%PDF")
      ["application/pdf", "pdf"]
    elsif amostra.lstrip.downcase.start_with?("<html", "<!doctype")
      ["text/html", "html"]
    else
      ["application/pdf", "pdf"] # fallback
    end
  end

  def modelo_param
    m = params[:modelo].to_i
    MODELOS.include?(m) ? m : 55
  end

  # Resolve o destinatario: usa cod_pessoa existente (busca) se informado.
  def resolver_cliente
    cod = params[:cod_pessoa].presence
    cod ? Pessoa.find_by(cod_pessoa: cod) : nil
  end

  # Operacao escolhida no topo (fallback: NF avulsa / Venda).
  def operacao_escolhida
    OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
      OperacaoFiscal.find_by(nome: "NF avulsa") ||
      OperacaoFiscal.find_by(nome: "Venda (NF-e)")
  end

  # Re-exibe o form (new) com os dados que o usuario digitou e a mensagem de erro,
  # SEM redirect (que recarregaria o new vazio). Preserva itens/destinatario.
  def reexibir_form(mensagem)
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = operacao_escolhida
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)
    @finalidades = DocumentoFiscal::FINALIDADES
    @finalidade_sel = params[:finalidade]
    @cod_pessoa_sel = params[:cod_pessoa]
    @nome_pessoa_sel = Pessoa.find_by(cod_pessoa: @cod_pessoa_sel)&.nome if @cod_pessoa_sel.present?
    # Cabecalho fiscal digitado (observacoes, pagamentos, transporte, NF ref).
    @info_adicional_sel       = params[:info_adicional]
    @info_adicional_fisco_sel = params[:info_adicional_fisco]
    @pagamentos_sel           = pagamentos_param || []
    @transporte_sel           = transporte_param || {}
    @cobranca_sel             = cobranca_param || {}
    @consumidor_final_sel     = params[:consumidor_final]
    @chave_referenciada_sel   = params[:chave_referenciada]
    @fatura_numero_base       = params[:fatura_numero].presence ||
                                @cobranca_sel.dig("fatura", "numero")
    @itens_preenchidos = itens_raw
    flash.now[:alert] = mensagem
    render :new, status: :unprocessable_entity
  end

  # Itens no formato CRU (strings do form), para re-exibir sem perder formatacao.
  def itens_raw
    brutos = params[:itens]
    brutos = brutos.values if brutos.is_a?(ActionController::Parameters)
    Array(brutos).map { |i| i.permit(:cod_produto, :cod_cor, :quantidade, :valorunitario, :cod_perfil_tributario, :cfop, :nome_produto).to_h }
                 .reject { |i| i["cod_produto"].blank? }
  end

  # Monta a lista de itens a partir dos params do form (ja parseada p/ emissao).
  # Espera params[:itens] = [{ cod_produto, cod_cor, quantidade, valorunitario,
  #                            cod_perfil_tributario, cfop }, ...]
  def itens_param
    itens_raw.map do |i|
      {
        cod_produto:           i["cod_produto"],
        cod_cor:               i["cod_cor"],
        quantidade:            MoedaBr.parse(i["quantidade"]),
        valorunitario:         MoedaBr.parse(i["valorunitario"]),
        cod_perfil_tributario: i["cod_perfil_tributario"].presence,
        cfop:                  i["cfop"].presence
      }
    end
  end

  # Cabecalho fiscal do form (observacoes, pagamentos, transporte e NF
  # referenciada), ja limpo/normalizado. Usado para persistir no rascunho e
  # montar o avulso. Vazio quando o form nao enviou nada (retrocompativel).
  def cabecalho_param
    chave = params[:chave_referenciada].to_s.gsub(/\D/, "").presence
    cf = params[:consumidor_final].to_s.strip.downcase
    {
      info_adicional:       params[:info_adicional].to_s.strip.first(2000).presence,
      info_adicional_fisco: params[:info_adicional_fisco].to_s.strip.first(2000).presence,
      pagamentos:           pagamentos_param,
      transporte:           transporte_param,
      cobranca:             cobranca_param,
      consumidor_final:     (cf if %w[sim nao].include?(cf)),
      chave_referenciada:   ((chave if chave&.length == 44)) # so grava chave de 44 digitos
    }
  end

  # Cobranca (duplicatas a prazo) do form: params[:parcelas] = [{numero,
  # vencimento, valor}]. Descarta linhas sem vencimento ou valor <= 0. Monta a
  # fatura (numero do cod_vendaempresa quando houver) com a soma. Retorna nil
  # quando nao ha parcelas (builder nao envia cobr).
  def cobranca_param
    brutos = params[:parcelas]
    brutos = brutos.values if brutos.is_a?(ActionController::Parameters)
    parcelas = Array(brutos).filter_map do |p|
      h = p.respond_to?(:permit) ? p.permit(:numero, :vencimento, :valor).to_h : p.to_h
      venc = normalizar_data(h["vencimento"])
      valor = MoedaBr.parse(h["valor"])
      next if venc.blank? || valor.to_d <= 0
      { "numero" => h["numero"].to_s.strip.first(60).presence,
        "vencimento" => venc, "valor" => valor.to_d.to_f }
    end
    return nil if parcelas.empty?

    total = parcelas.sum { |x| x["valor"].to_d }
    { "fatura" => { "numero" => params[:fatura_numero].to_s.strip.first(60).presence,
                    "valor" => total.to_f, "valor_liquido" => total.to_f },
      "parcelas" => parcelas }
  end

  # Numero-base da fatura a partir da venda vinculada: cod_vendaempresa (ou
  # cod_venda como fallback). nil quando a NF nao vem de venda (avulsa pura).
  def numero_base_da_venda(cod_venda)
    return nil if cod_venda.blank?
    venda = Venda.where(cod_empresa: current_collaborator.cod_empresa).find_by(cod_venda: cod_venda)
    return nil if venda.nil?
    (venda.cod_vendaempresa.presence || venda.cod_venda).to_s
  end

  # Converte data do form (dd/mm/aaaa ou aaaa-mm-dd) para ISO aaaa-mm-dd. nil se invalida.
  def normalizar_data(v)
    s = v.to_s.strip
    return nil if s.blank?
    if s =~ %r{\A(\d{2})/(\d{2})/(\d{4})\z}
      "#{$3}-#{$2}-#{$1}"
    elsif s =~ /\A\d{4}-\d{2}-\d{2}\z/
      s
    else
      (Date.parse(s).strftime("%Y-%m-%d") rescue nil)
    end
  end

  # Pagamento do form: params[:pagamentos] = [{forma, valor, descricao}] (forma
  # UNICA por nota). Valor em branco => usa o total da nota (default). Descarta
  # quando a forma nao e valida. Retorna nil quando nao ha forma informada
  # (builder usa o padrao: 99 = total da nota).
  def pagamentos_param
    brutos = params[:pagamentos]
    brutos = brutos.values if brutos.is_a?(ActionController::Parameters)
    total = total_itens_param
    lista = Array(brutos).filter_map do |p|
      h = p.respond_to?(:permit) ? p.permit(:forma, :valor, :descricao).to_h : p.to_h
      forma = h["forma"].to_s.strip
      next unless DocumentoFiscal::FORMAS_PAGAMENTO.key?(forma)
      valor = MoedaBr.parse(h["valor"]).to_d
      # Valor em branco/0: usa o total da nota (exceto forma 90 = sem pagamento).
      valor = total if valor <= 0 && forma != "90"
      { "forma" => forma, "valor" => valor.to_f,
        "descricao" => h["descricao"].to_s.strip.first(60).presence }
    end
    lista.presence
  end

  # Total dos itens do form (base para o valor do pagamento quando em branco).
  def total_itens_param
    itens_param.sum { |it| it[:quantidade].to_d * it[:valorunitario].to_d }
  end

  # Dados de transporte do form (jsonb). A transportadora e uma Pessoa do
  # cadastro (busca igual ao destinatario): guardamos cod_pessoa + um snapshot
  # do nome. Veiculo so faz sentido com transportadora; volumes so quando o
  # toggle "possui_volumes" esta ligado. Por ora apenas captura/persiste; o
  # envio ao provedor sera ligado na etapa de transporte.
  #
  # Retorna nil quando so ha a modalidade "9 - sem transporte" e nada mais
  # (nada relevante a guardar).
  def transporte_param
    t = params[:transporte]
    return nil if t.blank?
    t = t.permit(:modalidade_frete, :transportadora_cod_pessoa, :transportadora_nome,
                 :placa, :placa_uf, :rntc,
                 :possui_volumes, :volume_qtd, :volume_especie, :volume_marca,
                 :volume_numero, :peso_liquido, :peso_bruto).to_h

    # Sem transportadora selecionada: descarta os dados de veiculo (so fazem
    # sentido com transportadora).
    if t["transportadora_cod_pessoa"].to_s.strip.blank?
      t.delete("transportadora_cod_pessoa")
      t.delete("transportadora_nome")
      %w[placa placa_uf rntc].each { |k| t.delete(k) }
    end

    # Volumes so quando o toggle esta ligado; senao descarta os campos.
    if t["possui_volumes"].to_s != "1"
      %w[possui_volumes volume_qtd volume_especie volume_marca volume_numero
         peso_liquido peso_bruto].each { |k| t.delete(k) }
    end

    t = t.reject { |_, v| v.to_s.strip.blank? }
    # So "modalidade_frete=9" (sem transporte) e nada mais = nada a guardar.
    return nil if t.empty? || (t.keys == ["modalidade_frete"] && t["modalidade_frete"].to_s == "9")
    t
  end

  # Monta o DocumentoAvulso (fonte neutra p/ o builder) com itens + cabecalho.
  # cab: hash de cabecalho_param (params do form) OU do documento persistido.
  def montar_avulso(empresa:, cliente:, itens:, cab:)
    Fiscal::DocumentoAvulso.new(
      empresa: empresa, cliente: cliente, itens: itens,
      info_adicional:       cab[:info_adicional],
      info_adicional_fisco: cab[:info_adicional_fisco],
      pagamentos:           cab[:pagamentos],
      transporte:           cab[:transporte],
      cobranca:             cab[:cobranca],
      consumidor_final:     cab[:consumidor_final],
      chave_referenciada:   cab[:chave_referenciada]
    )
  end

  # Cabecalho fiscal a partir de um DocumentoFiscal persistido (rascunho), para
  # reconstruir o avulso na emissao de nota ja salva.
  def cabecalho_do_documento(documento)
    {
      info_adicional:       documento.info_adicional,
      info_adicional_fisco: documento.info_adicional_fisco,
      pagamentos:           documento.pagamentos,
      transporte:           documento.transporte,
      cobranca:             documento.cobranca,
      consumidor_final:     documento.consumidor_final,
      chave_referenciada:   documento.chave_referenciada
    }
  end

  # Atributos de cabecalho fiscal para gravar no DocumentoFiscal (rascunho).
  def atributos_cabecalho_documento
    cab = cabecalho_param
    {
      info_adicional:       cab[:info_adicional],
      info_adicional_fisco: cab[:info_adicional_fisco],
      pagamentos:           cab[:pagamentos],
      transporte:           cab[:transporte],
      cobranca:             cab[:cobranca],
      consumidor_final:     cab[:consumidor_final],
      chave_referenciada:   cab[:chave_referenciada]
    }
  end

  # Grava (aprende) o perfil tributario escolhido na fiscal_produto da empresa,
  # SOMENTE quando o produto ainda nao tem perfil. Nao sobrescreve um perfil
  # ja definido. Nao derruba o fluxo em caso de erro (loga).
  def aprender_perfil_fiscal_produto(cod_produto, cod_perfil_tributario)
    registro = FiscalProduto.find_or_initialize_by(
      cod_empresa: current_collaborator.cod_empresa,
      cod_produto: cod_produto
    )
    return if registro.cod_perfil_tributario.present? # ja tem — nao sobrescreve
    registro.cod_perfil_tributario = cod_perfil_tributario
    registro.save!
  rescue => e
    Rails.logger.error("[NotasAvulsas#aprender_perfil_fiscal_produto] produto #{cod_produto}: #{e.class} - #{e.message}")
  end

  # Converte os itens de uma VENDA para o formato que gravar_itens_rascunho
  # espera (mesmo shape de itens_param). O perfil tributario vem da fiscal_produto
  # da empresa (com fallback); o CFOP fica em branco (resolvido na tela/emissao
  # pela regra do perfil). Agrupa nada: 1 itemvenda = 1 item da nota.
  def itens_da_venda(venda)
    venda.itensvenda.map do |iv|
      fiscal = FiscalProduto.para(current_collaborator.cod_empresa, iv.cod_produto)
      {
        cod_produto:           iv.cod_produto,
        cod_cor:               iv.cod_cor,
        quantidade:            iv.quantidade.to_d,
        valorunitario:         iv.valorunitario.to_d,
        cod_perfil_tributario: fiscal.cod_perfil_tributario.presence,
        cfop:                  nil
      }
    end
  end

  # Monta a cobranca (duplicatas) a partir das contas a receber da venda
  # (contaspagrec). Numero da parcela = "<cod_vendaempresa>-<n>". Retorna nil
  # quando a venda nao tem contas. So vira duplicata NA NF se a forma de
  # pagamento escolhida for a prazo (≠ 99/90) — senao fica salvo mas nao e enviado.
  def cobranca_da_venda(venda)
    contas = venda.contas.to_a
    return nil if contas.empty?

    base = venda.cod_vendaempresa.presence || venda.cod_venda
    parcelas = contas.each_with_index.filter_map do |c, i|
      venc = c.dtvencimento
      valor = c.valorparcela.to_d
      next if venc.blank? || valor <= 0
      numero = c.numeroparcela.presence || (i + 1)
      { "numero" => "#{base}-#{numero}",
        "vencimento" => venc.strftime("%Y-%m-%d"),
        "valor" => valor.to_f }
    end
    return nil if parcelas.empty?

    total = parcelas.sum { |x| x["valor"].to_d }
    { "fatura" => { "numero" => base.to_s, "valor" => total.to_f, "valor_liquido" => total.to_f },
      "parcelas" => parcelas }
  rescue => e
    Rails.logger.error("[NotasAvulsas#cobranca_da_venda] venda #{venda&.cod_venda}: #{e.class} - #{e.message}")
    nil
  end

  # Grava os itens (parseados por itens_param) como documento_fiscal_item do
  # rascunho. nome_produto e um snapshot (do proprio produto).
  def gravar_itens_rascunho(documento, itens)
    itens.each_with_index do |it, idx|
      prod = Produto.find_by(cod_produto: it[:cod_produto])
      documento.itens.create!(
        cod_produto:           it[:cod_produto],
        cod_cor:               it[:cod_cor].presence,
        nome_produto:          prod&.nome,
        quantidade:            it[:quantidade],
        valorunitario:         it[:valorunitario],
        cod_perfil_tributario: it[:cod_perfil_tributario].presence,
        cfop:                  it[:cfop].presence&.to_s&.gsub(/\D/, "").presence,
        ordem:                 idx
      )
    end
  end

  # Itens persistidos de um rascunho no formato que DocumentoAvulso/ItemAvulso
  # espera (para emitir). Mesmo shape de itens_param.
  def itens_para_avulso(documento)
    documento.itens.order(:ordem, :cod_documento_fiscal_item).map do |item|
      {
        cod_produto:           item.cod_produto,
        cod_cor:               item.cod_cor,
        quantidade:            item.quantidade.to_d,
        valorunitario:         item.valorunitario.to_d,
        cod_perfil_tributario: item.cod_perfil_tributario.presence,
        cfop:                  item.cfop.presence
      }
    end
  end

  # Itens persistidos de um rascunho, no MESMO formato cru que itens_raw produz,
  # para a view (new) reexibir o form preenchido na edicao.
  def itens_do_rascunho(documento)
    documento.itens.order(:ordem, :cod_documento_fiscal_item).map do |item|
      {
        "cod_produto"           => item.cod_produto.to_s,
        "cod_cor"               => item.cod_cor.to_s,
        # Quantidade: campo HTML type=number (nao aceita virgula) — usa ponto,
        # sem casas desnecessarias (inteiro vira "1", nao "1.0").
        "quantidade"            => formata_quantidade(item.quantidade),
        # Valor unitario: campo de texto em padrao BR ("1.200,00").
        "valorunitario"         => MoedaBr.format(item.valorunitario),
        "cod_perfil_tributario" => item.cod_perfil_tributario.to_s,
        "cfop"                  => item.cfop.to_s,
        "nome_produto"          => item.nome_produto.to_s
      }
    end
  end

  # Quantidade para o campo type=number: inteiro sem ".0" (ex. "2"); fracionado
  # mantem o ponto decimal (ex. "2.5"), que e o que o input numerico aceita.
  def formata_quantidade(valor)
    bd = valor.to_d
    bd.frac.zero? ? bd.to_i.to_s : bd.to_s("F")
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
