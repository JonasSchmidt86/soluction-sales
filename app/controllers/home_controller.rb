class HomeController < ApplicationController
  layout 'public'
  
  def index
    # Buscar produtos ativos com imagem e publicados no scope/model Produto
    @produtos = Produto.ativos.com_imagem_e_publicado.limit(6) rescue []
                      
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
    @produtos = Produto.ativos.com_imagem_e_publicado rescue []
  rescue => e
    @produtos = []
    logger.error "Erro na página de portfólio: #{e.message}"
  end
end