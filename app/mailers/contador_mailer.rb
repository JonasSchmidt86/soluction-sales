# Envia o pacote de XMLs (saidas) ao contador. USA O BREVO (SMTP transacional),
# isolado via delivery_method_options — NAO altera o SMTP global (Gmail), que
# continua atendendo reset de senha e demais e-mails.
#
# Brevo: smtp-relay.brevo.com:587 (STARTTLS). login/key nas credentials
# (brevo_smtp_login / brevo_smtp_key).
class ContadorMailer < ApplicationMailer
  BREVO_SMTP = {
    address:              "smtp-relay.brevo.com",
    port:                 587,
    domain:               "mail.moveisrosa.shop",
    authentication:       :login,
    enable_starttls_auto: true,
    enable_starttls:      true,   # 587 = STARTTLS (nao SSL direto)
    ssl:                  false,  # evita "wrong version number" (SSL na porta STARTTLS)
    tls:                  false,
    openssl_verify_mode:  "none",
    user_name:            Rails.application.credentials.brevo_smtp_login,
    password:             Rails.application.credentials.brevo_smtp_key,
    open_timeout:         15,
    read_timeout:         20
  }.freeze

  # Envia o pacote (zip/xlsx) de XMLs do periodo para o(s) e-mail(s) do contador.
  #   destinatarios: String ou Array de e-mails
  #   remetente:     e-mail "from" (deve ser remetente VERIFICADO no Brevo)
  #   anexo_nome / anexo_conteudo / anexo_mime: o arquivo gerado pelo provedor
  def enviar_notas(destinatarios:, remetente:, assunto:, corpo:,
                   anexo_nome:, anexo_conteudo:, anexo_mime:)
    attachments[anexo_nome] = { mime_type: anexo_mime, content: anexo_conteudo } if anexo_conteudo.present?
    @corpo = corpo
    mail(
      to:   Array(destinatarios),
      from: remetente,
      subject: assunto,
      delivery_method_options: BREVO_SMTP
    )
  end
end
