# Resultado neutro do ObterArquivoNotaFiscal: o arquivo (XML ou PDF) de um
# documento fiscal ja existente na base do provedor, recuperado pela chave.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalArquivo
  attr_reader :xml_base64, :pdf_base64, :erro

  def initialize(xml_base64: nil, pdf_base64: nil, erro: nil)
    @xml_base64 = xml_base64.presence
    @pdf_base64 = pdf_base64.presence
    @erro       = erro.presence
  end

  def sucesso?
    erro.nil? && (xml_base64.present? || pdf_base64.present?)
  end

  # Conteudo binario decodificado (XML ou PDF), pronto para send_data.
  def conteudo
    b64 = xml_base64.presence || pdf_base64.presence
    b64 && Base64.decode64(b64)
  end

  def pdf?
    pdf_base64.present?
  end

  def xml?
    xml_base64.present?
  end
end
