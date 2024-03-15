class CpfCnpjValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    value = value.to_s.gsub(/[^0-9]/, '')

    if value.length == 11 && !validar_cpf(value)
      record.errors[attribute] << ('Não é um CPF válido')
    elsif value.length == 14 && !validar_cnpj(value)
      record.errors[attribute] << ('Não é um CNPJ válido')
    end
  end

  private

  def validar_cpf(cpf)
    cpf = cpf.gsub(/[^0-9]/, '')  # Remove caracteres não numéricos

    return false if cpf.length != 11

    # Calcula o primeiro dígito verificador
    soma = 0
    (0..8).each do |i|
      soma += cpf[i].to_i * (10 - i)
    end

    dv1 = (soma % 11) < 2 ? 0 : 11 - (soma % 11)

    # Calcula o segundo dígito verificador
    soma = 0
    (0..8).each do |i|
      soma += cpf[i].to_i * (11 - i)
    end

    soma += dv1 * 2
    dv2 = (soma % 11) < 2 ? 0 : 11 - (soma % 11)

    # Verifica se os dígitos verificadores calculados são iguais aos fornecidos no CPF
    cpf[-2, 2] == "#{dv1}#{dv2}"

  end
    
  def validar_cnpj(cnpj)
    cnpj = cnpj.gsub(/[^0-9]/, '')  # Remove caracteres não numéricos
      
    return false if cnpj.length != 14
      
    # Calcula o primeiro dígito verificador
    soma = 0
    peso = 5
    (0..11).each do |i|
      soma += cnpj[i].to_i * peso
      peso = peso == 2 ? 9 : peso - 1
    end
    dv1 = (soma % 11) < 2 ? 0 : 11 - (soma % 11)
      
    # Calcula o segundo dígito verificador
    soma = 0
    peso = 6
    (0..12).each do |i|
      soma += cnpj[i].to_i * peso
      peso = peso == 2 ? 9 : peso - 1
    end
    dv2 = (soma % 11) < 2 ? 0 : 11 - (soma % 11)
  
    # Verifica se os dígitos verificadores calculados são iguais aos fornecidos no CNPJ
    cnpj[-2, 2].to_i == "#{dv1}#{dv2}".to_i
  end      
      
end