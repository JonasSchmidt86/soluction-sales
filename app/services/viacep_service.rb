class ViacepService
  include HTTParty
  base_uri 'https://viacep.com.br/ws'

  def self.get_address_by_cep(cep)
    puts "----------------- #{cep}"
    response = get("/#{cep}/json/")
    if response.success?
      parsed_response = JSON.parse(response.body)
      puts "----------------- #{parsed_response.inspect}"
      return {
        street: parsed_response['logradouro']&.upcase,
        city: parsed_response['localidade']&.upcase,
        state: parsed_response['uf']&.upcase,
        ibge: parsed_response['ibge']
      }
    else
      return nil
    end
  end

  def self.get_id_cidade(cep)
    address = self.get_address_by_cep(cep)
    return nil if address.blank?

    # Primeiro tenta buscar pelo código IBGE (cod_municipio)
    if address[:ibge].present?
      cidade = Cidade.select(:cod_cidade).find_by(cod_municipio: address[:ibge])
      return cidade.cod_cidade if cidade.present?
    end

    # Fallback: busca pelo nome da cidade, se necessário
    return nil if address[:city].blank?

    city_without_accents = I18n.transliterate(address[:city])
    cidade = Cidade.select(:cod_cidade)
                   .where("nome ILIKE ?", "%#{city_without_accents}%")
                   .first
    cidade&.cod_cidade
  end
end
