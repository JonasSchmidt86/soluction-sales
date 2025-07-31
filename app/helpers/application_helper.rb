module ApplicationHelper

    def post_date(date)
      # formatting date: Aug, 31 2007 - 9:55PM
      # date.strftime("posted on %b, %m %Y - %H:%M")
      date.in_time_zone.strftime("%d/%m/%Y")
    end

    def post_datetime(date)
      l(date, format: :default)
    end

    def valor_por_extenso(valor)
      reais = valor.to_i
      centavos = ((valor - reais) * 100).round

      extenso_reais = reais.to_words(locale: :pt_br)
      extenso_centavos = centavos > 0 ? centavos.to_words(locale: :pt_br) : nil

      resultado = "#{extenso_reais} rea"
      resultado += "is" if reais != 1

      if extenso_centavos
        resultado += "is #{extenso_centavos} centavo"
        resultado += "is" if centavos != 1
      end

      resultado.capitalize
    end
end
