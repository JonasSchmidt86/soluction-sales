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
    
  end
  