class CollaboratorMailer < ApplicationMailer
    # O remetente deve pertencer a um domínio verificado no SendGrid
    # (Sender Authentication / DKIM). Enviar "de" gmail.com via SendGrid
    # é bloqueado/marcado como spam pela política DMARC do Gmail.
    default from: 'nao-responda@moveisrosa.shop'
  
    def set_password_email(collaborator, token)
      @collaborator = collaborator
      @url = edit_collaborator_password_url(reset_password_token: token)
      
      mail(to: @collaborator.email, subject: 'Defina sua senha de acesso')
    end
  end
  