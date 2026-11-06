# Agrega site_events para o dashboard de analytics do portfolio publico
# (CollaboratorsBackoffice::Report::RepSiteAnalyticsController).
#
# FUSO: created_at ja guarda o horario de Sao Paulo (ENV['TZ'], config.time_zone e
# default_timezone :local), entao hora / dia / dia da semana saem DIRETO de created_at,
# SEM converter fuso (converter de novo deslocaria 3 h).
#
# O periodo e [inicio, fim] em datas (inclusive). Tambem calcula o periodo anterior,
# de mesmo tamanho e imediatamente antes, para as variacoes dos cartoes.
class SiteAnalyticsReport
  TOP = 10
  PAGINAS_VISTAS = [SiteEvent::VIEW_PORTFOLIO, SiteEvent::VIEW_PRODUTO].freeze
  PREFIXO_DEMO = "demo-".freeze

  Resultado = Struct.new(
    :inicio, :fim, :dias, :inicio_anterior, :fim_anterior,
    :totais, :anteriores, :variacoes,
    :diario, :por_hora, :por_dia_semana,
    :produtos, :buscas, :cidades, :origem, :paises,
    :demo_no_periodo, :demo_total,
    keyword_init: true
  ) do
    # Nenhum evento no periodo (a tela mostra um aviso em vez de zeros).
    def vazio?
      totais.values_at(:visitas, :views_produto, :cliques_whatsapp, :buscas).all?(&:zero?)
    end
  end

  def initialize(inicio, fim)
    @inicio = inicio
    @fim    = fim
    @dias   = (fim - inicio).to_i + 1
    @faixa  = inicio.beginning_of_day..fim.end_of_day

    @fim_anterior    = inicio - 1
    @inicio_anterior = @fim_anterior - (@dias - 1)
    @faixa_anterior  = @inicio_anterior.beginning_of_day..@fim_anterior.end_of_day
  end

  def call
    atuais    = totais(@faixa)
    anteriores = totais(@faixa_anterior)

    Resultado.new(
      inicio: @inicio, fim: @fim, dias: @dias,
      inicio_anterior: @inicio_anterior, fim_anterior: @fim_anterior,
      totais: atuais, anteriores: anteriores,
      variacoes: atuais.keys.index_with { |k| variacao(atuais[k], anteriores[k]) },
      diario: serie_diaria, por_hora: por_hora, por_dia_semana: por_dia_semana,
      produtos: produtos, buscas: buscas, cidades: cidades, origem: origem, paises: paises,
      demo_no_periodo: demo.where(created_at: @faixa).count, demo_total: demo.count
    )
  end

  private

  def eventos(faixa = @faixa)
    SiteEvent.where(created_at: faixa)
  end

  def demo
    SiteEvent.where("visitor_id LIKE ?", "#{PREFIXO_DEMO}%")
  end

  def totais(faixa)
    visitas, views, cliques, buscas, visitantes, visitantes_clique, produtos_vistos, tempo = eventos(faixa).pick(
      Arel.sql("COUNT(*) FILTER (WHERE event_type = 'view_portfolio')"),
      Arel.sql("COUNT(*) FILTER (WHERE event_type = 'view_produto')"),
      Arel.sql("COUNT(*) FILTER (WHERE event_type = 'click_whatsapp')"),
      Arel.sql("COUNT(*) FILTER (WHERE event_type = 'busca')"),
      Arel.sql("COUNT(DISTINCT visitor_id)"),
      Arel.sql("COUNT(DISTINCT visitor_id) FILTER (WHERE event_type = 'click_whatsapp')"),
      Arel.sql("COUNT(DISTINCT cod_produto) FILTER (WHERE event_type = 'view_produto')"),
      Arel.sql("ROUND(AVG(duracao_seg) FILTER (WHERE event_type = 'view_produto'))")
    )

    {
      visitas: visitas.to_i, views_produto: views.to_i, cliques_whatsapp: cliques.to_i,
      buscas: buscas.to_i, visitantes: visitantes.to_i, visitantes_clique: visitantes_clique.to_i,
      produtos_vistos: produtos_vistos.to_i, tempo_medio: tempo&.to_i,
      conversao: visitantes.to_i.zero? ? nil : (visitantes_clique.to_i * 100.0 / visitantes.to_i).round(1)
    }
  end

  # Variacao percentual contra o periodo anterior; nil quando nao ha base (0 ou ausente).
  def variacao(atual, anterior)
    return nil if atual.nil? || anterior.nil? || anterior.to_f.zero?

    ((atual - anterior) * 100.0 / anterior).round(1)
  end

  # Dia a dia: visitas ao portfolio e cliques no WhatsApp (dias sem evento = 0).
  def serie_diaria
    visitas = por_data(SiteEvent::VIEW_PORTFOLIO)
    cliques = por_data(SiteEvent::CLICK_WHATSAPP)
    dias = (@inicio..@fim).to_a
    {
      labels:  dias.map { |d| d.strftime("%d/%m") },
      visitas: dias.map { |d| visitas[d].to_i },
      cliques: dias.map { |d| cliques[d].to_i }
    }
  end

  def por_data(tipo)
    eventos.where(event_type: tipo).group(Arel.sql("created_at::date")).count
           .transform_keys { |k| k.respond_to?(:to_date) ? k.to_date : Date.parse(k.to_s) }
  end

  # Paginas vistas (portfolio + produto) por hora do dia, 0..23.
  def por_hora
    h = eventos.where(event_type: PAGINAS_VISTAS).group(Arel.sql("EXTRACT(HOUR FROM created_at)::int")).count
    (0..23).map { |i| h.sum { |k, v| k.to_i == i ? v : 0 } }
  end

  # Paginas vistas por dia da semana: indice 0 = domingo ... 6 = sabado.
  def por_dia_semana
    d = eventos.where(event_type: PAGINAS_VISTAS).group(Arel.sql("EXTRACT(DOW FROM created_at)::int")).count
    (0..6).map { |i| d.sum { |k, v| k.to_i == i ? v : 0 } }
  end

  def produtos
    sql = <<~SQL
      SELECT v.cod_produto,
             COALESCE(NULLIF(p.titulo, ''), p.nome) AS nome,
             v.views, v.visitantes, v.tempo_medio, COALESCE(w.cliques, 0) AS cliques
        FROM (SELECT cod_produto, COUNT(*) AS views, COUNT(DISTINCT visitor_id) AS visitantes,
                     ROUND(AVG(duracao_seg)) AS tempo_medio
                FROM site_events
               WHERE event_type = 'view_produto' AND created_at BETWEEN :ini AND :fim
               GROUP BY cod_produto
               ORDER BY views DESC, cod_produto
               LIMIT :top) v
        LEFT JOIN (SELECT cod_produto, COUNT(*) AS cliques
                     FROM site_events
                    WHERE event_type = 'click_whatsapp' AND created_at BETWEEN :ini AND :fim
                    GROUP BY cod_produto) w ON w.cod_produto = v.cod_produto
        LEFT JOIN produto p ON p.cod_produto = v.cod_produto
       ORDER BY v.views DESC, v.cod_produto
    SQL
    consulta = SiteEvent.sanitize_sql_array([sql, { ini: @faixa.begin, fim: @faixa.end, top: TOP }])

    SiteEvent.connection.select_all(consulta).map do |r|
      views = r["views"].to_i
      cliques = r["cliques"].to_i
      {
        cod_produto: r["cod_produto"].to_i,
        nome: r["nome"].presence || "Produto ##{r['cod_produto']}",
        views: views, visitantes: r["visitantes"].to_i,
        tempo_medio: r["tempo_medio"]&.to_i, cliques: cliques,
        conversao: views.zero? ? nil : (cliques * 100.0 / views).round(1)
      }
    end
  end

  # Termos mais buscados + quantos produtos o catalogo publico acha HOJE para cada um
  # (mesma busca do site: Produto.busca_texto). 0 produtos = demanda sem oferta.
  def buscas
    catalogo = Produto.ativos.com_imagem_e_publicado
    eventos.where(event_type: SiteEvent::BUSCA)
           .group(:termo_busca)
           .order(Arel.sql("COUNT(*) DESC"), :termo_busca)
           .limit(TOP)
           .pluck(:termo_busca, Arel.sql("COUNT(*)"), Arel.sql("COUNT(DISTINCT visitor_id)"))
           .map do |termo, qtd, pessoas|
      {
        termo: termo, buscas: qtd.to_i, visitantes: pessoas.to_i,
        produtos: catalogo.busca_texto(termo).reorder(nil).distinct.count("produto.cod_produto")
      }
    end
  end

  def cidades
    eventos.where(pais: "BR").where.not(cidade: nil)
           .group(:cidade, :estado)
           .order(Arel.sql("COUNT(DISTINCT visitor_id) DESC"), :cidade)
           .limit(TOP)
           .pluck(:cidade, :estado, Arel.sql("COUNT(DISTINCT visitor_id)"))
           .map { |cidade, uf, n| { cidade: cidade, estado: uf, visitantes: n.to_i } }
  end

  # Visitantes por origem. Quem aparece em mais de um grupo (IP que mudou de pais)
  # entra em cada um; por isso os percentuais usam a soma dos grupos como base.
  def origem
    por = eventos.group(Arel.sql(
      "CASE WHEN pais = 'BR' THEN 'brasil' WHEN pais IS NULL THEN 'desconhecido' ELSE 'exterior' END"
    )).distinct.count(:visitor_id)
    { brasil: por["brasil"].to_i, exterior: por["exterior"].to_i, desconhecido: por["desconhecido"].to_i }
  end

  def paises
    eventos.where.not(pais: [nil, "BR"])
           .group(:pais)
           .order(Arel.sql("COUNT(DISTINCT visitor_id) DESC"), :pais)
           .limit(8)
           .pluck(Arel.sql("MAX(pais_nome)"), :pais, Arel.sql("COUNT(DISTINCT visitor_id)"))
           .map { |nome, codigo, n| { pais: nome.presence || codigo, codigo: codigo, visitantes: n.to_i } }
  end
end
