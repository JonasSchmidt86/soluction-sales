class CollaboratorMailer < ApplicationMailer
    default from: 'suporte@seu-dominio.com'
  
    def set_password_email(collaborator, token)
      @collaborator = collaborator
      @url = edit_collaborator_password_url(reset_password_token: token)
      
      mail(to: @collaborator.email, subject: 'Defina sua senha de acesso')
    end
  end
  