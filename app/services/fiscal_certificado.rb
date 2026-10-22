# Resultado neutro da verificação do CERTIFICADO DIGITAL da empresa no provedor
# (Brasil NFe: VerificarCertificado). Diz se o certificado cadastrado está
# válido/expirado e até quando. Usado no painel de Configuração Fiscal para
# mostrar a validade (que hoje não aparece) e alertar vencimento.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalCertificado
  attr_reader :data_expiracao, :mensagem, :avisos, :bruto

  def initialize(sucesso:, expirado: nil, data_expiracao: nil, mensagem: nil, avisos: nil, bruto: nil)
    @sucesso        = sucesso ? true : false
    @expirado       = expirado.nil? ? nil : (expirado ? true : false)
    @data_expiracao = parse_data(data_expiracao)
    @mensagem       = mensagem.presence
    @avisos         = Array(avisos)
    @bruto          = bruto
  end

  # A consulta em si deu certo (conseguiu ler a situação do certificado).
  def sucesso?
    @sucesso
  end

  # Certificado expirado (true) / válido (false) / desconhecido (nil).
  def expirado?
    @expirado
  end

  # Certificado presente e dentro da validade.
  def valido?
    @sucesso && @expirado == false
  end

  # Dias até expirar (negativo = já expirou). nil quando não há data.
  def dias_para_expirar
    return nil if @data_expiracao.nil?
    (@data_expiracao - Date.current).to_i
  end

  # Está perto de vencer (dentro de `janela` dias, padrão 30) e ainda não venceu.
  def proximo_vencimento?(janela = 30)
    d = dias_para_expirar
    !d.nil? && d >= 0 && d <= janela
  end

  private

  def parse_data(valor)
    return valor if valor.is_a?(Date)
    s = valor.to_s.strip
    return nil if s.empty?
    Date.parse(s) rescue nil
  end
end
