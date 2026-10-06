# Resultado neutro do ObterArquivosPorPeriodo: um pacote compactado (.zip de
# XML/PDF) ou uma planilha (.xlsx) com os documentos de um periodo, para
# auditoria/contabilidade.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalPacote
  attr_reader :quantidade, :erro, :avisos, :bruto

  def initialize(sucesso:, base64: nil, quantidade: 0, excel: false,
                 erro: nil, avisos: nil, bruto: nil)
    @sucesso    = sucesso ? true : false
    @base64     = base64.presence
    @quantidade = quantidade.to_i
    @excel      = excel ? true : false
    @erro       = erro.presence
    @avisos     = Array(avisos)
    @bruto      = bruto
  end

  def sucesso?
    @sucesso && @base64.present?
  end

  def excel?
    @excel
  end

  # Conteudo binario decodificado (zip ou xlsx), pronto para send_data.
  def conteudo
    @base64 && Base64.decode64(@base64)
  end

  def extensao
    excel? ? "xlsx" : "zip"
  end

  def mime
    excel? ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" : "application/zip"
  end
end
