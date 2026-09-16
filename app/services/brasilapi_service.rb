class BrasilapiService
  include HTTParty
  base_uri 'https://brasilapi.com.br/api'

  # Busca os dados cadastrais de um CNPJ na BrasilAPI.
  # Retorna:
  #   { data: {...} }               quando encontra a empresa
  #   { error: :not_found }         quando o CNPJ nao existe (404)
  #   { error: :rate_limited }      quando a BrasilAPI limita as requisicoes (429)
  #   { error: :unavailable }       para os demais erros / instabilidade
  def self.get_company_by_cnpj(cnpj)
    cnpj = cnpj.to_s.gsub(/\D/, '')
    return { error: :invalid } unless cnpj.length == 14

    response = get("/cnpj/v1/#{cnpj}")

    case response.code
    when 200
      { data: normalize(JSON.parse(response.body)) }
    when 404
      { error: :not_found }
    when 429
      { error: :rate_limited }
    else
      { error: :unavailable }
    end
  rescue JSON::ParserError, SocketError, Net::OpenTimeout, Net::ReadTimeout, HTTParty::Error
    { error: :unavailable }
  end

  def self.normalize(data)

    endereco = [data['descricao_tipo_de_logradouro'], data['logradouro']]
                 .map { |p| p.to_s.strip }
                 .reject(&:blank?)
                 .join(' ')

    {
      razao_social: data['razao_social']&.upcase,
      nome_fantasia: data['nome_fantasia']&.upcase,
      cep: data['cep'],
      endereco: endereco.upcase.presence,
      numero: data['numero'].to_s.strip.presence,
      complemento: data['complemento']&.upcase.presence,
      bairro: data['bairro']&.upcase.presence,
      telefone: data['ddd_telefone_1'].to_s.strip.presence,
      email: data['email']&.downcase.presence,
      data_abertura: format_date(data['data_inicio_atividade']),
      municipio: data['municipio']&.upcase,
      uf: data['uf']&.upcase,
      ibge: data['codigo_municipio_ibge'].presence
    }
  end

  # Converte a data da API (AAAA-MM-DD) para o formato usado no formulario (DD/MM/AAAA).
  def self.format_date(value)
    return nil if value.blank?

    Date.parse(value).strftime('%d/%m/%Y')
  rescue ArgumentError, TypeError
    nil
  end

  # Descobre o cod_cidade interno a partir do CNPJ, priorizando o codigo IBGE
  # e caindo para a busca por nome (mesma estrategia do ViacepService).
  def self.get_id_cidade(company)
    return nil if company.blank?

    if company[:ibge].present?
      cidade = Cidade.select(:cod_cidade).find_by(cod_municipio: company[:ibge])
      return cidade.cod_cidade if cidade.present?
    end

    return nil if company[:municipio].blank?

    city_without_accents = I18n.transliterate(company[:municipio])
    cidade = Cidade.select(:cod_cidade)
                   .where("nome ILIKE ?", "%#{city_without_accents}%")
                   .first
    cidade&.cod_cidade
  end
end
