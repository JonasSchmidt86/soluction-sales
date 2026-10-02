# Resultado neutro da consulta de STATUS da SEFAZ (ConsultarStatusSefaz).
#
# operante? = serviço da SEFAZ disponível para o modelo consultado
# (código SEFAZ 107 "Serviço em Operação"). A consulta é sempre em produção.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalStatus
  attr_reader :codigo, :mensagem, :ambiente, :uf, :avisos, :bruto

  def initialize(operante:, codigo: nil, mensagem: nil, ambiente: nil, uf: nil, avisos: nil, bruto: nil)
    @operante = operante ? true : false
    @codigo   = codigo
    @mensagem = mensagem.presence
    @ambiente = ambiente
    @uf       = uf
    @avisos   = Array(avisos)
    @bruto    = bruto
  end

  def operante?
    @operante
  end
end
