class HomeController < ApplicationController
  layout 'public'
  
  def index
    # Buscar produtos ativos com imagem e publicados no scope/model Produto
    @produtos = Produto.ativos.com_imagem_e_publicado.limit(7) rescue []
                      
    # Buscar contatos de WhatsApp ativos com foto
    @colaboradores = WhatsappContact.all.order(:id).select do |contact|
      contact.photo.attached?
    end rescue []
  rescue => e
    @produtos = []
    @colaboradores = []
    logger.error "Erro na página inicial: #{e.message}"
  end

  def produto
    @produto = Produto.find_by(cod_produto: params[:cod_produto])
    @cod_cor = params[:cod_cor]

    return redirect_to(root_path) unless @produto

    # Analytics: visualizacao do produto (sem cor, dedupe de 30 min). O evento (novo
    # ou o ja existente da janela) e exposto para o beacon de tempo de permanencia.
    @evento = registrar_evento(SiteEvent::VIEW_PRODUTO, cod_produto: @produto.cod_produto)
  rescue => e
    logger.error "Erro ao carregar produto: #{e.message}"
    redirect_to root_path
  end

  def portfolio
    escopo = Produto.ativos.com_imagem_e_publicado

    # Busca textual por nome, título ou descrição do produto.
    # unaccent() torna a busca insensível a acentos (sofa = sofá) e o
    # ILIKE mantém a busca insensível a maiúsculas/minúsculas.
    escopo = escopo.busca_texto(params[:q]) if params[:q].present?

    # Filtro por grupo (categoria genérica já existente)
    if params[:grupo].present?
      escopo = escopo.where(produto: { grupo: params[:grupo] })
    end

    @produtos = escopo.page(params[:page]).per(19)

    # Opções do filtro: apenas grupos que têm produto publicado
    @grupos = Grupo
      .joins(produtos: :empresaprodutos)
      .where(empresaprodutos: { publicado: true })
      .distinct
      .order(:nomegrupo)

    # Analytics: visita ao portfolio (uma por sessao de 30 min) e, se houve busca
    # por texto, o termo pesquisado.
    registrar_evento(SiteEvent::VIEW_PORTFOLIO)
    registrar_evento(SiteEvent::BUSCA, termo_busca: params[:q]) if params[:q].present?
  rescue => e
    @produtos = Produto.none.page(params[:page])
    @grupos = []
    logger.error "Erro na página de portfólio: #{e.message}"
  end

  private

  # Registra um evento de analytics sem nunca afetar a pagina: SiteAnalytics ja
  # absorve erros e ignora bots, HEAD e usuarios logados no sistema.
  def registrar_evento(tipo, **dados)
    SiteAnalytics.track(event_type: tipo, request: request, cookies: cookies, **dados)
  rescue StandardError => e
    logger.error "[Analytics] #{e.class}: #{e.message}"
    nil
  end

end