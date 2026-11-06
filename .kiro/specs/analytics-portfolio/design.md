# Design — Analytics do Portfólio Público

## Visão geral

Rastrear interações de clientes nas páginas públicas gravando eventos numa tabela
dedicada (`site_events`). O registro é feito no servidor para visitas/views e via
requisição assíncrona (AJAX/beacon) para o clique de WhatsApp e o tempo de
permanência. A identificação de pessoa única usa um cookie anônimo. A cidade é
resolvida por base GeoIP local (GeoLite2) e só cidade/estado são gravados. Um
relatório no backoffice agrega os números por período.

Stack: Rails 7.1, PostgreSQL. Sem login nas páginas públicas (layout `public`).

## Arquitetura

```
Visitante (navegador)
  │
  ├─ GET /portfolio ───────────► HomeController#portfolio ─► SiteAnalytics.track(:view_portfolio)
  ├─ GET /produto/:cod/:cor ───► HomeController#produto   ─► SiteAnalytics.track(:view_produto)
  ├─ POST /a/whatsapp (fetch) ─► SiteEventsController#whatsapp ─► SiteAnalytics.track(:click_whatsapp)
  └─ POST /a/tempo (sendBeacon)► SiteEventsController#tempo   ─► atualiza duração do view_produto
                                           │
                                           ▼
                                   SiteAnalytics (serviço)
                                   - dedupe por janela (30 min)
                                   - filtro de bot (user-agent)
                                   - cookie anônimo (visitor_id)
                                   - GeoIP local → cidade/estado
                                           │
                                           ▼
                                   site_events (tabela)
                                           │
                                           ▼
    Backoffice: Report::SiteAnalyticsController#index ─► agregações ─► view do relatório
```

## Modelo de dados

### Tabela `site_events`

| coluna        | tipo       | notas                                                        |
|---------------|------------|--------------------------------------------------------------|
| id            | bigint PK  |                                                              |
| event_type    | string     | `view_portfolio`, `view_produto`, `click_whatsapp`, `busca`  |
| cod_produto   | bigint null| preenchido em `view_produto` e `click_whatsapp` (quando houver) |
| termo_busca   | string null| termo normalizado; preenchido só no evento `busca`           |
| visitor_id    | string     | id anônimo do cookie (uuid)                                  |
| cidade        | string null| resolvida por GeoIP                                          |
| estado        | string null| UF resolvida por GeoIP (só Brasil)                           |
| pais          | string(2) null| código ISO do país (ex.: `BR`, `US`); chave de agrupamento |
| pais_nome     | string(80) null| nome do país em pt-BR (só exibição)                       |
| duracao_seg   | integer null| tempo de permanência (só `view_produto`, via beacon)        |
| created_at    | datetime   | data/hora do evento (base para horário/período)             |

Observações:
- **Não** há coluna de IP nem user-agent (decisão de privacidade).
- `cod_produto` referencia `produto.cod_produto` logicamente (sem FK rígida, para
  não quebrar se um produto for removido; o relatório faz `LEFT JOIN`).

### Índices (para o relatório não ficar lento)
- `index_site_events_on_event_type_and_created_at` (event_type, created_at)
- `index_site_events_on_cod_produto` (cod_produto)
- `index_site_events_on_visitor_id_and_created_at` (visitor_id, created_at) — usado
  no dedupe de 30 min e na contagem de visitantes únicos.
- `index_site_events_on_termo_busca` (termo_busca) — ranking de buscas.

### Migração
`CreateSiteEvents` cria a tabela e os índices acima.

## Componentes

### 1. `SiteAnalytics` (serviço — `app/services/site_analytics.rb`)

Responsável por decidir se registra e por gravar o evento. Recebe o `request`,
os `cookies` e os parâmetros do evento.

Métodos:
- `self.track(event_type:, request:, cookies:, cod_produto: nil, termo_busca: nil)`
  1. `return if bot?(request.user_agent)` — filtra crawlers.
  2. `vid = visitor_id(cookies)` — lê/cria o cookie anônimo.
  3. `return if duplicado?(event_type, vid, cod_produto)` — dedupe de 30 min
     (consulta o último evento igual do mesmo visitor na janela).
  4. `local = GeoIpResolver.call(request.remote_ip)` (cidade, estado, país).
  5. `SiteEvent.create!(...)` e retorna o evento (para o caso do view_produto,
     cujo id vai para o front medir o tempo).
- `self.bot?(user_agent)` — regex com padrões conhecidos (`bot`, `crawl`, `spider`,
  `slurp`, `bingpreview`, `facebookexternalhit`, etc.).
- `self.visitor_id(cookies)` — retorna o uuid do cookie `mr_vid`; se não existir,
  gera `SecureRandom.uuid` e grava cookie permanente (1 ano), `httponly`.
- `self.duplicado?(type, vid, cod_produto, termo_busca)` — dedupe por janela de 30
  min considerando visitor + (cod_produto ou termo_busca, conforme o tipo).
- `self.normaliza_termo(q)` — `q.to_s.strip.downcase` + remoção de acentos (unaccent),
  usado para agrupar buscas equivalentes.

Erros no serviço são capturados e logados; **nunca** derrubam a requisição
principal (o site funciona mesmo se o analytics falhar).

### 2. `GeoIpResolver` (`app/services/geo_ip_resolver.rb`)

- Usa a gem `maxmind-db` lendo o arquivo `GeoLite2-City.mmdb`.
- `self.call(ip)` → `GeoIpResolver::Local` (`cidade`, `estado`, `pais`, `pais_nome`,
  mais `brasil?`/`exterior?`). Brasil: cidade+UF+país. Exterior: só o país (a coluna
  `estado` guarda UF brasileira; siglas de outros países seriam ambíguas). Não
  resolvido / IP local / sem base: tudo `nil`.
- Carrega o reader uma vez (memoizado) para não reabrir o arquivo a cada evento.
- O arquivo `.mmdb` fica em `db/geoip/GeoLite2-City.mmdb` (fora do versionamento;
  baixado no deploy via conta gratuita MaxMind).
- Se o arquivo não existir, `call` retorna `[nil, nil]` sem erro (degrada suave).

### 3. Registro nas páginas públicas (`HomeController`)

- `portfolio`: ao final da action, `SiteAnalytics.track(event_type: "view_portfolio", ...)`.
  SE `params[:q]` estiver preenchido, também `SiteAnalytics.track(event_type: "busca",
  termo_busca: normaliza(params[:q]), ...)`. A normalização (minúsculo, sem acento,
  trim) fica no serviço, reaproveitando a mesma lógica da busca (`unaccent`).
- `produto`: `@evento = SiteAnalytics.track(event_type: "view_produto", cod_produto: @produto.cod_produto, ...)`.
  O `@evento&.id` é exposto na view para o beacon de tempo referenciar.
- Ambos envoltos em `rescue` para não afetar a renderização.

### 4. Clique de WhatsApp e tempo (rota pública)

Rotas novas (fora do backoffice, no layout público):
```ruby
post "a/whatsapp", to: "site_events#whatsapp"   # registra click_whatsapp
post "a/tempo",    to: "site_events#tempo"      # atualiza duracao_seg do view_produto
```

`SiteEventsController` (`ActionController::Base`, sem auth, com CSRF tratado):
- `whatsapp`: lê `cod_produto` (opcional) do corpo, chama `SiteAnalytics.track(:click_whatsapp)`,
  responde `head :ok`.
- `tempo`: lê `evento_id` e `segundos`, valida que é um `view_produto`, atualiza
  `duracao_seg` (aceita só valores plausíveis, ex.: 0..3600), responde `head :ok`.

CSRF: como vêm de `fetch`/`sendBeacon`, incluir o `csrf-token` no corpo/header ou
usar `skip_before_action :verify_authenticity_token` restrito a estas duas actions
(são endpoints de escrita idempotente e sem dado sensível).

### 5. Front-end (layout público + views)

- **Cookie anônimo**: criado no servidor (serviço). Não precisa JS para isso.
- **Clique WhatsApp** (`_whatsapp_modal`): no clique do link, dispara
  `fetch("/a/whatsapp", {method:"POST", body: {cod_produto}})` e deixa o link
  abrir normalmente (não previne o default; o fetch roda em paralelo).
- **Tempo de permanência** (`produto.html.erb`): script que
  - marca `inicio = Date.now()` ao carregar;
  - pausa/retoma conforme `document.visibilitychange` (não conta aba em background);
  - no `pagehide`/`visibilitychange→hidden`, envia
    `navigator.sendBeacon("/a/tempo", {evento_id, segundos})`.
  - Só roda se houver `@evento&.id` (produto registrado, não bot).

### 6. Relatório no backoffice

Controller: `CollaboratorsBackoffice::Report::SiteAnalyticsController#index`
(herda de `CollaboratorsBackofficeController`, respeitando o controle de acesso).

- Lê `data_inicio`/`data_fim` (padrão: últimos 30 dias).
- Agregações (SQL com `GROUP BY`, usando os índices):
  - Total `view_portfolio`, total `view_produto`, total `click_whatsapp`.
  - Visitantes únicos: `COUNT(DISTINCT visitor_id)` no período.
  - Ranking: top produtos por `COUNT(*)` de `view_produto` + `AVG(duracao_seg)` +
    nº de `click_whatsapp` do mesmo produto no período, `LEFT JOIN produto` para o nome.
  - Por horário: `GROUP BY EXTRACT(HOUR FROM created_at)`.
  - Por cidade/estado (Brasil): `WHERE pais = 'BR' GROUP BY cidade, estado ORDER BY COUNT(*) DESC`.
  - Por país: `GROUP BY pais` (nome via `MAX(pais_nome)`), e resumo Brasil × exterior
    (`pais = 'BR'` vs demais).
  - Buscas mais feitas: `WHERE event_type = 'busca' GROUP BY termo_busca ORDER BY COUNT(*) DESC`.
- View: cards com os totais, tabela do ranking (produto, views, tempo médio,
  cliques de WhatsApp), um gráfico/tabela por hora, uma tabela por cidade e uma
  tabela de buscas mais feitas. Segue o visual dos demais relatórios em
  `collaborators_backoffice/report/`.

Rota (no namespace `collaborators_backoffice`):
```ruby
get "report_site_analytics", to: "report/site_analytics#index", as: :report_site_analytics
```
O link no menu "Comunicação" fica para um momento posterior (combinado).

## Dependências novas
- Gem `maxmind-db` (leitura do `.mmdb`).
- Arquivo `GeoLite2-City.mmdb` (não versionado; baixado no ambiente).

## Tratamento de erros
- Falha do analytics (serviço/geoip): captura + log, nunca propaga.
- Beacon/fetch: falha é ignorada no cliente; o link do WhatsApp sempre abre.
- Relatório: valida datas; intervalo inválido cai no padrão de 30 dias.

## Privacidade (LGPD)
- Não persiste IP nem user-agent.
- `visitor_id` é aleatório e não identifica a pessoa.
- Guarda apenas país e (Brasil) cidade/estado agregáveis, data/hora e produto.

## Estratégia de testes
- Serviço `SiteAnalytics`: dedupe de 30 min, filtro de bot, criação de visitor_id.
- `GeoIpResolver`: retorna `[nil,nil]` quando sem base/IP local; cidade quando há base.
- Controller público: responde `:ok` e não exige auth; CSRF tratado.
- Relatório: agregações corretas por período (contagens, únicos, ranking, hora, cidade).
- Verificação de que o site renderiza mesmo com o analytics desabilitado/falhando.
