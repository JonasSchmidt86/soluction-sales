class ApplicationMailer < ActionMailer::Base
  # Remetente padrão do domínio autenticado no Brevo.
  default from: 'nao-responda@mail.moveisrosa.shop'
  layout 'mailer'
end
