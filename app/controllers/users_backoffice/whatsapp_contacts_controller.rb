
module UsersBackoffice
  class WhatsappContactsController < ApplicationController
    # Nenhum filtro de autenticação aqui!
    def index
      @empresas = Empresa.includes(:whatsapp_contacts).all
    end

    def show
      @whatsapp_contact = WhatsappContact.find(params[:id])
    end
  end
end
