# Gera dados de DEMONSTRACAO em site_events, para desenhar e validar o relatorio de
# analytics do portfolio publico (spec: .kiro/specs/analytics-portfolio).
#
# - Todo evento demo tem visitor_id com prefixo "demo-": site_analytics:demo_clear
#   remove SO esses, sem tocar nos eventos reais.
# - DRY-RUN por padrao (so mostra o resumo); APPLY=1 grava.
# - Idempotente: ao gravar, apaga os eventos demo anteriores e recria.
# - Quase determinista: o mesmo SEED= (padrao 20261110) no mesmo dia gera dados
#   praticamente iguais (so os eventos mais recentes dependem da hora atual).
# - Recusa rodar em producao (Rails.env.production?) sem FORCE=1.
# - Respeita as regras do SiteAnalytics: 1 visita ao portfolio por sessao, produto e
#   busca sem repeticao na janela de 30 min. Horarios no fuso de Sao Paulo: o app roda
#   com TZ=America/Sao_Paulo e default_timezone :local (config/environment.rb e
#   application.rb), entao o banco guarda o horario de Sao Paulo sem conversao.
#
# Uso:
#   rails site_analytics:demo_seed                           # simulacao
#   APPLY=1 rails site_analytics:demo_seed                   # 1200 visitas em 45 dias
#   APPLY=1 VISITAS=3000 DIAS=60 rails site_analytics:demo_seed
#   APPLY=1 rails site_analytics:demo_clear                  # remove so os eventos demo
unless defined?(SiteAnalyticsDemo)
  module SiteAnalyticsDemo
    PREFIXO = "demo-".freeze
    FUSO    = "America/Sao_Paulo".freeze

    # [peso, cidade, UF, pais, nome do pais]; Brasil = cidade + UF; exterior = so o pais;
    # ultima linha = IP que o GeoIP nao conseguiu localizar.
    LOCAIS = [
      [28, "Toledo", "PR", "BR", "Brasil"], [13, "Cascavel", "PR", "BR", "Brasil"],
      [9, "Marechal Cândido Rondon", "PR", "BR", "Brasil"], [5, "Palotina", "PR", "BR", "Brasil"],
      [5, "Assis Chateaubriand", "PR", "BR", "Brasil"], [4, "Foz do Iguaçu", "PR", "BR", "Brasil"],
      [4, "Nova Santa Rosa", "PR", "BR", "Brasil"], [3, "Maripá", "PR", "BR", "Brasil"],
      [3, "Medianeira", "PR", "BR", "Brasil"], [3, "Guaíra", "PR", "BR", "Brasil"],
      [2, "Ouro Verde do Oeste", "PR", "BR", "Brasil"], [2, "Umuarama", "PR", "BR", "Brasil"],
      [2, "Santa Helena", "PR", "BR", "Brasil"], [2, "São Pedro do Iguaçu", "PR", "BR", "Brasil"],
      [2, "Curitiba", "PR", "BR", "Brasil"], [1.5, "Maringá", "PR", "BR", "Brasil"],
      [1.5, "Francisco Beltrão", "PR", "BR", "Brasil"], [1.5, "Chapecó", "SC", "BR", "Brasil"],
      [1.5, "São Paulo", "SP", "BR", "Brasil"], [1, "Porto Alegre", "RS", "BR", "Brasil"],
      [2.5, nil, nil, "PY", "Paraguai"], [0.8, nil, nil, "US", "EUA"],
      [0.6, nil, nil, "PT", "Portugal"], [0.4, nil, nil, "AR", "Argentina"],
      [3.5, nil, nil, nil, nil]
    ].freeze

    # Termos ja normalizados (como o SiteAnalytics grava). Alguns nao existem no catalogo
    # de proposito: "rack", "cama box"... mostram demanda sem oferta no relatorio.
    BUSCAS = [
      [10, "sofa"], [8, "cadeira"], [7, "mesa"], [6, "guarda roupa"], [5, "roupeiro"], [5, "rack"],
      [4, "painel tv"], [4, "cama box"], [4, "poltrona"], [4, "mesa de jantar"],
      [3, "cadeira de jantar"], [3, "cama"], [3, "colchao"], [3, "buffet"], [2, "aparador"],
      [2, "escrivaninha"], [2, "estante"], [2, "sapateira"], [2, "banqueta"], [2, "puff"],
      [2, "comoda"], [2, "criado mudo"], [2, "sofa retratil"], [1.5, "mesa de centro"],
      [1.5, "mesa 6 cadeiras"], [1, "cadeira verona"], [1, "mesa monaco"], [1, "cozinha"],
      [1, "armario"], [1, "berco"]
    ].freeze

    # Peso de cada hora local (0..23): picos no almoco e a noite (19h-22h).
    PESOS_HORA = [0.6, 0.3, 0.2, 0.1, 0.1, 0.2, 0.8, 1.5, 2.5, 3.5, 4, 4.5,
                  5, 4.5, 4, 4, 4, 4.5, 5.5, 7, 8.5, 8, 6, 2.5].freeze
    # Peso por dia da semana (0 = domingo).
    DIAS_SEMANA = { 0 => 1.5, 1 => 0.9, 2 => 0.9, 3 => 1.0, 4 => 1.1, 5 => 1.2, 6 => 1.4 }.freeze

    module_function

    def gauss(rng)
      Math.sqrt(-2 * Math.log(1 - rng.rand)) * Math.cos(2 * Math::PI * rng.rand)
    end

    def indice_ponderado(rng, pesos)
      r = rng.rand * pesos.sum
      pesos.each_with_index { |p, i| r -= p; return i if r <= 0 }
      pesos.size - 1
    end

    # Tempo de permanencia: parte nao chega (beacon perdido), parte sai na hora e o
    # resto segue uma distribuicao log-normal (mediana ~42 s) com cauda longa.
    def duracao(rng)
      return nil if rng.rand < 0.08
      return rng.rand(1..6) if rng.rand < 0.2

      d = Math.exp(Math.log(42) + 0.85 * gauss(rng))
      d *= rng.rand(4.0..12.0) if rng.rand < 0.04
      d.round.clamp(1, 3600)
    end

    def sorteia_termos(rng, qtd)
      restantes = BUSCAS.dup
      Array.new(qtd) { restantes.delete_at(indice_ponderado(rng, restantes.map(&:first))).last }
    end

    def montar_visita(rng, inicio, visitante, agora, pop, prop)
      _, cidade, uf, pais, pais_nome = visitante[:local]
      base = { cod_produto: nil, termo_busca: nil, visitor_id: visitante[:id], cidade: cidade,
               estado: uf, pais: pais, pais_nome: pais_nome, duracao_seg: nil }
      eventos = []
      t = inicio
      add = lambda do |tipo, extra = {}|
        return false if t >= agora

        eventos << base.merge(event_type: tipo, created_at: t.utc).merge(extra)
        true
      end

      sorteio = rng.rand
      vistos  = [] # [cod_produto, duracao]

      if sorteio < 0.015
        add.(SiteEvent::CLICK_WHATSAPP) # veio da home e clicou no WhatsApp
      else
        direto = sorteio < 0.165 # abriu um link de produto compartilhado
        unless direto
          add.(SiteEvent::VIEW_PORTFOLIO)
          if rng.rand < 0.35
            sorteia_termos(rng, rng.rand < 0.7 ? 1 : 2).each do |termo|
              t += rng.rand(12..70)
              add.(SiteEvent::BUSCA, termo_busca: termo)
            end
          end
        end

        qtd = if direto
                rng.rand < 0.4 ? 2 : 1
              elsif rng.rand < 0.12
                0
              else
                n = 1
                n += 1 while rng.rand < 0.58 && n < 6
                n
              end

        candidatos = pop.keys
        escolhidos = Array.new([qtd, candidatos.size].min) do
          candidatos.delete_at(indice_ponderado(rng, candidatos.map { |c| pop[c] }))
        end

        escolhidos.each_with_index do |cod, i|
          t += rng.rand(8..60) unless direto && i.zero?
          dur = duracao(rng)
          break unless add.(SiteEvent::VIEW_PRODUTO, cod_produto: cod, duracao_seg: dur)

          vistos << [cod, dur]
          t += (dur || 20)
        end

        # Intencao de compra: cresce com o tempo no produto e com o "apelo" dele.
        melhor = vistos.max_by { |cod, dur| (dur || 25) * prop[cod] }
        score  = melhor ? (melhor[1] || 25) * prop[melhor[0]] : 0
        chance = if score > 120 then 0.16 elsif score > 45 then 0.05 elsif score > 0 then 0.015 else 0.0 end
        if rng.rand < chance
          [1, 1, 1, 1, 2, 2, 3].sample(random: rng).times do |i|
            t += rng.rand(5..45)
            add.(SiteEvent::CLICK_WHATSAPP, cod_produto: (i.zero? && rng.rand < 0.85 ? melhor[0] : nil))
          end
        end
      end

      visitante[:fim] = t
      eventos
    end

    def gerar(visitas:, dias:, seed:, codigos:)
      rng   = Random.new(seed)
      zona  = ActiveSupport::TimeZone[FUSO]
      hoje  = zona.today
      agora = Time.current

      pop = {}  # popularidade (Zipf) por produto
      prop = {} # propensao ao WhatsApp por produto
      codigos.shuffle(random: rng).each_with_index do |cod, i|
        pop[cod]  = 1.0 / (i + 1)**0.85
        prop[cod] = 0.6 + rng.rand * 1.6
      end

      pesos_dia = (0...dias).map do |d|
        peso = DIAS_SEMANA[(hoje - d).wday] * (1 + 0.012 * (dias - d)) # leve tendencia de alta
        peso *= 2.6 if dias > 12 && d == 11 # pico: post/promocao nas redes
        peso *= 1.6 if dias > 13 && d == 12
        peso
      end

      inicios = Array.new(visitas) do
        t = nil
        20.times do
          data = hoje - indice_ponderado(rng, pesos_dia)
          cand = zona.local(data.year, data.month, data.day, indice_ponderado(rng, PESOS_HORA), rng.rand(60), rng.rand(60))
          if cand < agora - 120
            t = cand
            break
          end
        end
        t || (agora - 3600 - rng.rand(86_000))
      end.sort

      visitantes = []
      pesos_loc  = LOCAIS.map(&:first)
      inicios.flat_map do |inicio|
        v = nil
        if visitantes.any? && rng.rand < 0.22 # visitante que volta (so se a sessao anterior ja acabou)
          3.times do
            c = visitantes[rng.rand(visitantes.size)]
            if c[:fim] < inicio - 31.minutes
              v = c
              break
            end
          end
        end
        unless v
          v = { id: format("%s%05d", PREFIXO, visitantes.size + 1), local: LOCAIS[indice_ponderado(rng, pesos_loc)], fim: inicio }
          visitantes << v
        end
        montar_visita(rng, inicio, v, agora, pop, prop)
      end
    end

    def resumo(eventos)
      por_tipo = eventos.group_by { |e| e[:event_type] }.transform_values(&:size)
      visitantes = eventos.map { |e| e[:visitor_id] }.uniq.size
      visitas_portfolio = por_tipo[SiteEvent::VIEW_PORTFOLIO].to_i
      com_clique = eventos.select { |e| e[:event_type] == SiteEvent::CLICK_WHATSAPP }.map { |e| e[:visitor_id] }.uniq.size
      periodo = eventos.map { |e| e[:created_at].in_time_zone }.minmax
      puts "  eventos .............. #{eventos.size}"
      SiteEvent::TIPOS.each { |tipo| puts "    #{tipo.ljust(16)} #{por_tipo[tipo].to_i}" }
      puts "  visitantes unicos .... #{visitantes} (#{visitas_portfolio} visitas ao portfolio)"
      puts "  visitantes que clicaram no WhatsApp: #{com_clique} (#{(com_clique * 100.0 / visitantes).round(1)}%)"
      puts "  periodo (Sao Paulo) .. #{periodo.first.strftime('%d/%m/%Y %H:%M')} a #{periodo.last.strftime('%d/%m/%Y %H:%M')}"
    end

    def inteiro_env(nome, padrao, maximo)
      valor = ENV[nome].presence ? Integer(ENV[nome], 10, exception: false) : padrao
      abort "#{nome} deve ser um inteiro entre 1 e #{maximo}." unless valor && valor.between?(1, maximo)
      valor
    end

    def barrar_producao!
      return unless Rails.env.production? && ENV["FORCE"] != "1"

      abort "Recusado em producao: estes sao dados FALSOS. Use FORCE=1 apenas se tiver certeza."
    end
  end
end

namespace :site_analytics do
  desc "Gera eventos de DEMONSTRACAO no site_events (DRY-RUN; APPLY=1 grava; VISITAS, DIAS, SEED)"
  task demo_seed: :environment do
    SiteAnalyticsDemo.barrar_producao!
    visitas = SiteAnalyticsDemo.inteiro_env("VISITAS", 1200, 50_000)
    dias    = SiteAnalyticsDemo.inteiro_env("DIAS", 45, 365)
    seed    = SiteAnalyticsDemo.inteiro_env("SEED", 20_261_110, 2_000_000_000)
    apply   = ENV["APPLY"] == "1"

    codigos = Produto.ativos.com_imagem_e_publicado.to_a.map(&:cod_produto).uniq
    abort "Nenhum produto publicado com imagem para usar na demonstracao." if codigos.empty?

    demo_antes = SiteEvent.where("visitor_id LIKE ?", "#{SiteAnalyticsDemo::PREFIXO}%").count
    reais      = SiteEvent.where.not("visitor_id LIKE ?", "#{SiteAnalyticsDemo::PREFIXO}%").count
    puts "#{apply ? 'GRAVANDO' : 'DRY-RUN'}: #{visitas} visitas em #{dias} dias, #{codigos.size} produtos reais (seed #{seed})"
    puts "  ja existem #{demo_antes} eventos demo (serao substituidos) e #{reais} eventos reais (nao serao tocados)"

    eventos = SiteAnalyticsDemo.gerar(visitas: visitas, dias: dias, seed: seed, codigos: codigos)
    SiteAnalyticsDemo.resumo(eventos)

    if apply
      SiteEvent.transaction do
        SiteEvent.where("visitor_id LIKE ?", "#{SiteAnalyticsDemo::PREFIXO}%").delete_all
        eventos.each_slice(1000) { |lote| SiteEvent.insert_all(lote) }
      end
      puts "Gravados #{eventos.size} eventos demo. Para remover: APPLY=1 rails site_analytics:demo_clear"
    else
      puts "Nada foi gravado. Rode com APPLY=1 para gravar."
    end
  end

  desc "Remove os eventos de DEMONSTRACAO (visitor_id 'demo-%') do site_events (DRY-RUN; APPLY=1 apaga)"
  task demo_clear: :environment do
    SiteAnalyticsDemo.barrar_producao!
    escopo = SiteEvent.where("visitor_id LIKE ?", "#{SiteAnalyticsDemo::PREFIXO}%")
    total  = escopo.count
    if ENV["APPLY"] == "1"
      escopo.delete_all
      puts "Removidos #{total} eventos demo. Eventos reais restantes: #{SiteEvent.count}"
    else
      puts "DRY-RUN: #{total} eventos demo seriam removidos (reais: #{SiteEvent.count - total}). Use APPLY=1 para apagar."
    end
  end
end
