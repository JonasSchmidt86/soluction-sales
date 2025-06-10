class HomeController < ApplicationController
  layout 'public'
  
  def index
    @produtos = Produto.ativos.joins(:produto_imagens)
                      .where('produto_imagens.id IS NOT NULL')
                      .distinct.limit(6) rescue []
                      
    # Buscar contatos de WhatsApp ativos com foto
    @colaboradores = WhatsappContact.all.select do |contact|
      contact.photo.attached?
    end.first(4) rescue []
  rescue => e
    @produtos = []
    @colaboradores = []
    logger.error "Erro na página inicial: #{e.message}"
  end
end