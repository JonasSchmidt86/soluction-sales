# Envia ao cliente a NF-e autorizada, com o DANFE (PDF) e o XML em anexo.
# Usa o SMTP padrao da aplicacao (Brevo), igual aos demais e-mails do sistema.
class DocumentoFiscalMailer < ApplicationMailer
  # documento: DocumentoFiscal autorizado (modelo 55)
  # para:      e-mail do cliente
  # danfe_pdf / xml: conteudo binario dos arquivos
  # responder_para: e-mail de quem enviou (as respostas do cliente caem la, ja que
  #                 o remetente tecnico e "nao-responda")
  def enviar_nota(documento:, para:, nome_cliente:, danfe_pdf:, xml:, responder_para: nil)
    @documento    = documento
    @nome_cliente = nome_cliente
    @empresa_nome = documento.empresa&.nome.to_s.strip.presence || "Móveis Rosa"
    @numero       = documento.numero

    nome_base = documento.chave_acesso.presence || "nota-#{documento.cod_documento_fiscal}"
    attachments["danfe-#{nome_base}.pdf"] = { mime_type: "application/pdf", content: danfe_pdf }
    attachments["nfe-#{nome_base}.xml"]   = { mime_type: "application/xml", content: xml } if xml.present?

    mail(
      to:       para,
      from:     "#{@empresa_nome} <nao-responda@mail.moveisrosa.shop>",
      reply_to: responder_para.presence,
      subject:  "Nota fiscal #{@numero} - #{@empresa_nome}"
    )
  end
end
