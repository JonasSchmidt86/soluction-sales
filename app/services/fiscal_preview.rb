# Resultado neutro de uma PRE-VISUALIZACAO de documento fiscal.
#
# Diferente do FiscalResult (emissao), a pre-visualizacao NAO gera protocolo,
# chave nem se comunica com a SEFAZ: ela so devolve a representacao grafica
# (PDF) ou o XML do documento, para conferencia antes de emitir.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalPreview
  attr_reader :pdf_base64, :xml_base64, :erro, :avisos, :bruto

  # Um dos dois conteudos vem preenchido conforme o tipo de arquivo pedido:
  #   pdf_base64 (TipoArquivo=1) ou xml_base64 (TipoArquivo=0).
  def initialize(pdf_base64: nil, xml_base64: nil, erro: nil, avisos: nil, bruto: nil)
    @pdf_base64 = pdf_base64
    @xml_base64 = xml_base64
    @erro       = erro.presence
    @avisos     = Array(avisos)
    @bruto      = bruto
  end

  def sucesso?
    erro.nil? && (pdf_base64.present? || xml_base64.present?)
  end

  # Conteudo binario decodificado (PDF ou XML), pronto para send_data.
  def conteudo
    b64 = pdf_base64.presence || xml_base64.presence
    b64 && Base64.decode64(b64)
  end
end
