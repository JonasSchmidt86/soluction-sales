# Resultado neutro da consulta de SITUACAO de um documento (ConsultarNotaFiscal).
#
# Usado para reconciliar o status de uma nota cuja resposta de emissao se
# perdeu (timeout/queda), e para recuperar XML/PDF da nota autorizada.
#
# situacao: :autorizada / :cancelada / :rejeitada / :denegada / :enviada
#           (em processamento) / :desconhecida
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalConsulta
  attr_reader :situacao, :chave, :numero, :serie, :protocolo, :cod_sefaz,
              :mensagem, :xml_base64, :pdf_base64, :erro, :bruto

  def initialize(encontrada:, situacao: :desconhecida, chave: nil, numero: nil,
                 serie: nil, protocolo: nil, cod_sefaz: nil, mensagem: nil,
                 xml_base64: nil, pdf_base64: nil, erro: nil, bruto: nil)
    @encontrada = encontrada ? true : false
    @situacao   = situacao.to_sym
    @chave      = chave.presence
    @numero     = numero
    @serie      = serie
    @protocolo  = protocolo.presence
    @cod_sefaz  = cod_sefaz
    @mensagem   = mensagem.presence
    @xml_base64 = xml_base64.presence
    @pdf_base64 = pdf_base64.presence
    @erro       = erro.presence
    @bruto      = bruto
  end

  def encontrada?
    @encontrada
  end

  def autorizada?
    situacao == :autorizada
  end

  def cancelada?
    situacao == :cancelada
  end
end
