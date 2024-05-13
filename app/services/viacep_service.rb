class ViacepService

    include HTTParty
    base_uri 'https://viacep.com.br/ws'
  
    def self.get_address_by_cep(cep)
      response = get("/#{cep}/json/")
      if response.success?
        parsed_response = JSON.parse(response.body)
        return {
          street: parsed_response['logradouro'].upcase,
          city: parsed_response['localidade'].upcase,
          state: parsed_response['uf'].upcase
        }
      else
        return nil
      end
    end

    def self.get_id_cidade(cep)
      address = self.get_address_by_cep(cep)
      city_without_accents = I18n.transliterate(address[:city]);
      cidade = Cidade.select(:cod_cidade).where("nome ilike ? ", city_without_accents).first;
      cidade = cidade.cod_cidade if cidade.present?
    end
    
  end
  