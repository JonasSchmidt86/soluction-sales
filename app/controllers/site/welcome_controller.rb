class Site::WelcomeController < SiteController
  def index
        @title = 'Bem-vindo ao nosso site'
        @description = 'Explore nossos produtos e serviços.'
        @keywords = 'site, bem-vindo, produtos, serviços'
        @produtos = Produto
          .joins(produto_imagens: :imagem_attachment)
          .includes(produto_imagens: :imagem_attachment)
          .distinct
          .limit(10)

        @whatsapp_contacts = WhatsappContact.includes(:empresa, :funcionario).all.limit(10) # Carrega contatos do WhatsApp com empresa e funcionário associados
    end
end
