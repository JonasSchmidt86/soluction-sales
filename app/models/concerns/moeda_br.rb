# Normaliza valores monetarios no padrao brasileiro ("1.234,56") para
# BigDecimal, direto nos setters do atributo. Assim, nested attributes e
# forms podem enviar o valor com virgula/ponto de milhar sem o controller
# precisar fazer gsub manual.
#
# Uso:
#   class Itemvenda < ApplicationRecord
#     include MoedaBr
#     moeda_br :valorunitario, :valor_acrescimo, :valor_desconto
#   end
#
# Regra de parse:
#   - nil / "" -> deixa como veio (nao forca 0, respeita NOT NULL/validacao)
#   - Numeric (ja veio BigDecimal/Float) -> passa direto
#   - String "1.234,56" -> remove separador de milhar (.) e troca , por . => 1234.56
#   - String "1234.56" (ja em formato US, sem virgula) -> mantem
module MoedaBr
  extend ActiveSupport::Concern

  class_methods do
    def moeda_br(*attrs)
      attrs.each do |attr|
        define_method("#{attr}=") do |valor|
          super(MoedaBr.parse(valor))
        end
      end
    end
  end

  # Formata um valor numerico no padrao brasileiro ("1.234,56"): ponto de
  # milhar e virgula decimal, com `casas` decimais. Inverso de parse — usado
  # para pre-preencher campos de formulario que esperam valor em BR.
  #   MoedaBr.format(1200)      # => "1.200,00"
  #   MoedaBr.format(1234.5, 2) # => "1.234,50"
  #   MoedaBr.format(nil)       # => "0,00"
  def self.format(valor, casas = 2)
    numero = valor.is_a?(Numeric) ? valor : parse(valor)
    numero = 0 unless numero.is_a?(Numeric)
    inteiro, decimal = Kernel.format("%.#{casas}f", numero).split(".")
    sinal = inteiro.start_with?("-") ? "-" : ""
    inteiro = inteiro.delete("-")
    # Agrupa o inteiro em milhares com ponto.
    com_milhar = inteiro.reverse.gsub(/(\d{3})(?=\d)/, '\1.').reverse
    "#{sinal}#{com_milhar},#{decimal}"
  end

  # Converte um valor BR em BigDecimal. Retorna o proprio valor quando nao
  # da pra converter (nil, "", ou formato inesperado), deixando o Rails tratar.
  def self.parse(valor)
    return valor if valor.nil?
    return valor if valor.is_a?(Numeric)

    str = valor.to_s.strip
    return valor if str.empty?

    # Se tem virgula, assume padrao BR: ponto = milhar, virgula = decimal.
    if str.include?(",")
      str = str.delete(".").tr(",", ".")
    end

    # Mantem apenas digitos, sinal e um ponto decimal.
    limpo = str.gsub(/[^0-9.\-]/, "")
    return valor if limpo.empty? || limpo == "-" || limpo == "."

    BigDecimal(limpo)
  rescue ArgumentError, TypeError
    valor
  end
end
