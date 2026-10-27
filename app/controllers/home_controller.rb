class HomeController < ApplicationController
  layout 'public'
  
  def index
    # Buscar produtos ativos com imagem e publicados no scope/model Produto
    @produtos = Produto.ativos.com_imagem_e_publicado.limit(8) rescue []
                      
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
    
    redirect_to root_path unless @produto
  rescue => e
    logger.error "Erro ao carregar produto: #{e.message}"
    redirect_to root_path
  end

  def portfolio
    escopo = Produto.ativos.com_imagem_e_publicado

    # Busca textual por nome, título ou descrição do produto.
    # unaccent() torna a busca insensível a acentos (sofa = sofá) e o
    # ILIKE mantém a busca insensível a maiúsculas/minúsculas.
    if params[:q].present?
      termo = "%#{params[:q].strip}%"
      escopo = escopo.where(
        "unaccent(produto.nome) ILIKE unaccent(:q) OR " \
        "unaccent(produto.titulo) ILIKE unaccent(:q) OR " \
        "unaccent(produto.descricao) ILIKE unaccent(:q)",
        q: termo
      )
    end

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
  rescue => e
    @produtos = Produto.none.page(params[:page])
    @grupos = []
    logger.error "Erro na página de portfólio: #{e.message}"
  end

end