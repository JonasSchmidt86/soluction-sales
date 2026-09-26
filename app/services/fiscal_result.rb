# Resultado padronizado de qualquer operação do FiscalService.
# Neutro em relação ao provedor: Focus e Brasil NFe devem devolver isto,
# para o resto do sistema não depender do formato de cada API.
class FiscalResult
  attr_reader :status, :chave, :protocolo, :numero, :serie, :xml, :danfe_url, :mensagem, :bruto

  # status: :autorizado / :rejeitado / :cancelado / :processando / :erro
  def initialize(status:, chave: nil, protocolo: nil, numero: nil, serie: nil,
                 xml: nil, danfe_url: nil, mensagem: nil, bruto: nil)
    @status    = status.to_sym
    @chave     = chave
    @protocolo = protocolo
    @numero    = numero
    @serie     = serie
    @xml       = xml
    @danfe_url = danfe_url
    @mensagem  = mensagem
    @bruto     = bruto # resposta crua do provedor, para debug
  end

  def sucesso?
    %i[autorizado cancelado].include?(status)
  end

  def rejeitado?
    status == :rejeitado
  end

  def processando?
    status == :processando
  end
end
