class CollaboratorMailer < ApplicationMailer
    # Usando Gmail SMTP, o remetente deve ser a própria conta Gmail
    # (o Gmail reescreve/rejeita "from" de outros domínios).
    default from: 'moveisrosa.toledo@gmail.com'
  
    def set_password_email(collaborator, token)
      @collaborator = collaborator
      @url = edit_collaborator_password_url(reset_password_token: token)
      
      mail(to: @collaborator.email, subject: 'Defina sua senha de acesso')
    end
  end
  