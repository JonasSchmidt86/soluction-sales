class SiteController < ApplicationController

    layout 'public'

  def index
    # @produtos_destaque = Produto.where(destaque: true).includes(:produto_imagens)
    @produtos = Produto.includes(:produto_imagens).limit(10)
    @whatsapp_contacts = WhatsappContact.all
  end

end
