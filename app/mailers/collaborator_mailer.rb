class CollaboratorMailer < ApplicationMailer
    # Remetente do domínio autenticado no Brevo (DKIM/DMARC de mail.moveisrosa.shop).
    # O nome "Móveis Rosa" aparece como remetente; o endereço técnico fica discreto.
    default from: 'Móveis Rosa <nao-responda@mail.moveisrosa.shop>'
  
    def set_password_email(collaborator, token)
      @collaborator = collaborator
      @url = edit_collaborator_password_url(reset_password_token: token)
      
      mail(to: @collaborator.email, subject: 'Defina sua senha de acesso')
    end
  end
  