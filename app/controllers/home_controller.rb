class HomeController < ApplicationController
  layout 'public'
  
  def index
    @produtos = Produto.ativos
        .joins(:produto_imagens, :empresaprodutos)
        .where(
          'empresaprodutos.cod_produto = produto_imagens.cod_produto AND empresaprodutos.cod_cor = produto_imagens.cod_cor')
        .where(empresaprodutos: { publicado: true })
        .distinct.limit(6)
      #  rescue []
                      
    # Buscar contatos de WhatsApp ativos com foto
    @colaboradores = WhatsappContact.all.order(:id).select do |contact|
      contact.photo.attached?
    end.first(4) rescue []
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
end