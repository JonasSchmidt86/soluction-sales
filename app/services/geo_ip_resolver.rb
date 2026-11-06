# Estima a localizacao de um visitante a partir do IP, usando a base GeoIP
# LOCAL (MaxMind GeoLite2-City.mmdb). Tudo offline: nenhum IP sai do servidor.
#
# - Retorna um GeoIpResolver::Local (cidade, estado, pais, pais_nome).
#   * Brasil:  cidade + UF + pais "BR" ("Brasil").
#   * Exterior: so o pais (ex.: "US" / "Estados Unidos"); cidade e estado ficam
#     nil, pois a coluna "estado" guarda a UF brasileira e siglas de outros
#     paises seriam ambiguas (ex.: MA = Maranhao ou Massachusetts).
#   * Nao resolvido (sem base, IP privado/invalido, erro): tudo nil.
# - NUNCA levanta excecao: o analytics nao pode afetar o site.
# - A base e uma ESTIMATIVA (a cidade pode ser a do provedor, nao a do visitante).
#
# Local da base: db/geoip/GeoLite2-City.mmdb (ou a variavel GEOIP_DB_PATH).
# O arquivo e reaberto automaticamente quando e substituido (mtime muda), entao
# atualizar a base nao exige reiniciar o servidor.
#
# Obs.: a licenca do GeoLite exige manter a base atualizada (novas versoes
# toda terca e sexta). Ver docs/ do spec analytics-portfolio.
class GeoIpResolver
  Local = Struct.new(:cidade, :estado, :pais, :pais_nome) do
    def brasil?
      pais == PAIS_ALVO
    end

    def exterior?
      pais.present? && !brasil?
    end

    def resolvido?
      pais.present?
    end
  end

  DEFAULT_PATH = Rails.root.join("db", "geoip", "GeoLite2-City.mmdb").freeze
  PAIS_ALVO    = "BR".freeze
  VAZIO        = Local.new.freeze
  LOCK         = Mutex.new

  class << self
    # @param ip [String, nil]
    # @return [GeoIpResolver::Local] com campos nil quando desconhecidos
    def call(ip)
      return VAZIO if ip.blank?

      leitor = reader
      return VAZIO unless leitor

      extrair(leitor.get(ip.to_s))
    rescue StandardError => e
      # IP malformado, base corrompida etc.: degrada sem propagar.
      Rails.logger.warn("[GeoIpResolver] #{e.class}: #{e.message}")
      VAZIO
    end

    def db_path
      Pathname.new(ENV["GEOIP_DB_PATH"].presence || DEFAULT_PATH)
    end

    # true se a base local esta disponivel e abre corretamente.
    def disponivel?
      !reader.nil?
    end

    # Descarta o leitor em cache (uso em testes).
    def reset!
      LOCK.synchronize { @reader = nil; @mtime = nil }
    end

    private

    # Leitor em cache, reaberto se o arquivo mudou. Falha de abertura tambem e
    # guardada por mtime para nao reler um arquivo grande/invalido a cada request.
    def reader
      path = db_path
      return nil unless path.file?

      mtime = path.mtime
      return @reader if @mtime == mtime

      LOCK.synchronize do
        return @reader if @mtime == mtime

        @mtime  = mtime
        @reader = begin
          MaxMind::DB.new(path.to_s)
        rescue StandardError => e
          Rails.logger.error("[GeoIpResolver] base GeoIP invalida (#{path}): #{e.message}")
          nil
        end
      end
    end

    def extrair(registro)
      return VAZIO unless registro.is_a?(Hash)

      iso = registro.dig("country", "iso_code").to_s.strip.upcase
      return VAZIO unless iso.length == 2

      nomes_pais = registro.dig("country", "names") || {}
      pais_nome  = (nomes_pais["pt-BR"] || nomes_pais["en"]).to_s.strip.first(80).presence

      # Fora do Brasil: so o pais.
      return Local.new(nil, nil, iso, pais_nome) unless iso == PAIS_ALVO

      nomes_cidade = registro.dig("city", "names") || {}
      cidade = (nomes_cidade["pt-BR"] || nomes_cidade["en"]).to_s.strip.first(120).presence
      uf     = registro.dig("subdivisions", 0, "iso_code").to_s.strip.upcase.presence
      uf     = nil if uf && uf.length != 2

      Local.new(cidade, uf, iso, pais_nome)
    end
  end
end
