# Registra interacoes de visitantes nas paginas PUBLICAS do catalogo
# (portfolio, produto, busca, clique no WhatsApp) na tabela site_events.
#
# Regras (ver .kiro/specs/analytics-portfolio):
# - Visitante unico = cookie anonimo assinado (mr_vid, uuid, 1 ano). Nao identifica
#   ninguem. O IP e usado so para estimar pais/cidade (GeoIpResolver) e NAO e gravado.
# - Dedupe de 30 min por visitante: recarregar/filtrar/paginar o portfolio conta como
#   UMA visita; o mesmo produto ou a mesma busca repetidos tambem nao recontam.
#   Cliques no WhatsApp NUNCA sofrem dedupe (cada clique e uma intencao de contato).
# - Bots/crawlers, requisicoes HEAD e colaboradores/usuarios LOGADOS no sistema sao
#   ignorados (nao sujam a metrica; o user-agent nao e gravado).
# - NUNCA levanta excecao: falha do analytics nao pode afetar o site.
#
# Para testar manualmente, abra o site em janela anonima/deslogado: quem esta logado
# no ERP no mesmo navegador e ignorado de proposito.
class SiteAnalytics
  JANELA          = 30.minutes
  COOKIE          = :mr_vid
  COOKIE_VALIDADE = 1.year
  ESCOPOS_LOGADOS = %i[collaborator user].freeze
  TERMO_MIN       = 2
  TERMO_MAX       = 120
  UUID_FORMATO    = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  # Trechos de user-agent de crawlers, monitores e ferramentas automaticas.
  # Preview de link do WhatsApp/Facebook tambem entra: nao e uma pessoa.
  BOT_TRECHOS = %w[
    bot crawl spider slurp scrape headless lighthouse pagespeed gtmetrix pingdom
    uptime monitor curl/ wget python httpclient go-http-client axios node-fetch
    java/ libwww facebookexternalhit whatsapp/ bingpreview mediapartners
  ].freeze
  BOT_UA = Regexp.new(Regexp.union(BOT_TRECHOS).source, Regexp::IGNORECASE)

  class << self
    # Registra um evento e devolve o SiteEvent, ou nil quando nada foi gravado
    # (bot, usuario logado, termo/produto invalido, erro).
    #
    # Em caso de dedupe devolve o evento ja existente da janela (util para o beacon
    # de tempo de permanencia, que precisa do id do evento da visita).
    #
    # @param event_type [String] um de SiteEvent::TIPOS
    # @param request [ActionDispatch::Request]
    # @param cookies [ActionDispatch::Cookies::CookieJar]
    # @param cod_produto [Integer, String, nil] obrigatorio em view_produto
    # @param termo_busca [String, nil] obrigatorio em busca (sera normalizado)
    def track(event_type:, request:, cookies:, cod_produto: nil, termo_busca: nil)
      return nil unless SiteEvent::TIPOS.include?(event_type)
      return nil if ignorar?(request)

      # Base 10 explicita: Integer("010") seria 8 (octal) e Integer("0x1A") seria 26.
      cod_produto = Integer(cod_produto.to_s, 10, exception: false) unless cod_produto.nil?
      termo       = event_type == SiteEvent::BUSCA ? normaliza_termo(termo_busca) : nil

      return nil if event_type == SiteEvent::VIEW_PRODUTO && cod_produto.nil?
      return nil if event_type == SiteEvent::BUSCA && termo.nil?

      vid = visitor_id(cookies, request)

      recente = evento_recente(event_type, vid, cod_produto, termo)
      return recente if recente

      local = GeoIpResolver.call(request.remote_ip)
      SiteEvent.create!(
        event_type:  event_type,
        cod_produto: cod_produto,
        termo_busca: termo,
        visitor_id:  vid,
        cidade:      local.cidade,
        estado:      local.estado,
        pais:        local.pais,
        pais_nome:   local.pais_nome
      )
    rescue StandardError => e
      Rails.logger.error("[SiteAnalytics] #{e.class}: #{e.message}")
      nil
    end

    def bot?(user_agent)
      user_agent.blank? || user_agent.match?(BOT_UA)
    end

    # Id anonimo do cookie, SEM criar um novo (nil se nao existir/for invalido).
    # Usado para conferir que o beacon de tempo vem do mesmo visitante do evento.
    def visitor_atual(cookies)
      valor = cookies.signed[COOKIE]
      valor if valor.is_a?(String) && valor.match?(UUID_FORMATO)
    end

    # Minusculo, sem acento, espacos aparados e so caracteres "seguros", para
    # agrupar "Sofa", "sofá" e " SOFA " como a mesma busca. nil se vazio/curto demais.
    def normaliza_termo(termo)
      t = ActiveSupport::Inflector.transliterate(termo.to_s.downcase, "")
      t = t.gsub(%r{[^a-z0-9\s.,/+\-]}, " ").squish.first(TERMO_MAX).strip
      t.length >= TERMO_MIN ? t : nil
    end

    private

    def ignorar?(request)
      request.head? || bot?(request.user_agent) || usuario_logado?(request)
    end

    # Colaborador/usuario logado no sistema navegando no site publico nao conta.
    def usuario_logado?(request)
      warden = request.env["warden"]
      return false unless warden

      ESCOPOS_LOGADOS.any? { |escopo| warden.authenticated?(escopo) }
    end

    def visitor_id(cookies, request)
      atual = visitor_atual(cookies)
      return atual if atual

      novo = SecureRandom.uuid
      cookies.signed[COOKIE] = {
        value:     novo,
        expires:   COOKIE_VALIDADE.from_now,
        httponly:  true,
        same_site: :lax,
        secure:    request.ssl?
      }
      novo
    end

    # Evento equivalente dentro da janela de 30 min (nil se nao houver ou se o tipo
    # nao sofre dedupe).
    def evento_recente(event_type, vid, cod_produto, termo)
      return nil if event_type == SiteEvent::CLICK_WHATSAPP

      escopo = SiteEvent.where(event_type: event_type, visitor_id: vid)
                        .where("created_at > ?", JANELA.ago)
      escopo = escopo.where(cod_produto: cod_produto) if event_type == SiteEvent::VIEW_PRODUTO
      escopo = escopo.where(termo_busca: termo)       if event_type == SiteEvent::BUSCA
      escopo.order(created_at: :desc).first
    end
  end
end
