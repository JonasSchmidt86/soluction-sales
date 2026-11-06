# Plano de Implementação — Analytics do Portfólio Público

- [x] 1. Criar tabela e modelo `SiteEvent`
  - Migração `CreateSiteEvents` com colunas: `event_type`, `cod_produto`,
    `termo_busca`, `visitor_id`, `cidade`, `estado`, `duracao_seg`, `created_at`.
  - Índices: (event_type, created_at), (cod_produto), (visitor_id, created_at),
    (termo_busca).
  - Modelo `app/models/site_event.rb` com constantes dos tipos e scopes básicos
    (`no_periodo`, `do_tipo`).
  - _Requisitos: 1, 2, 3, 6_

- [x] 2. Implementar `GeoIpResolver`
  - `app/services/geo_ip_resolver.rb` lendo `db/geoip/GeoLite2-City.mmdb` via gem
    `maxmind-db` (adicionar ao Gemfile).
  - `call(ip)` retorna `GeoIpResolver::Local` (cidade, estado, país, nome do país);
    campos `nil` se sem base, IP local ou erro. Colunas `pais`/`pais_nome` criadas
    na migração `20261110000002`.
  - Reader memoizado. Degrada suave quando o arquivo não existe.
  - _Requisitos: 4_

- [x] 3. Implementar serviço `SiteAnalytics`
  - `app/services/site_analytics.rb` com `track`, `bot?`, `visitor_id`,
    `duplicado?` (dedupe 30 min) e `normaliza_termo`.
  - Cookie anônimo `mr_vid` (uuid, 1 ano, httponly).
  - Resolve cidade via `GeoIpResolver`; nunca persiste IP/user-agent.
  - Todo o fluxo protegido por rescue+log (não propaga erro).
  - _Requisitos: 1, 2, 3, 4, 5, 6_

- [x] 4. Registrar eventos nas páginas públicas (`HomeController`)
  - `portfolio`: registrar `view_portfolio`; se `params[:q]` presente, registrar `busca`.
  - `produto`: registrar `view_produto` e expor `@evento&.id` para o beacon.
  - Envolver em rescue para não afetar a renderização.
  - _Requisitos: 1, 2, 6_

- [x] 5. Rotas e controller público de eventos (clique + tempo)
  - Rotas `post "a/whatsapp"` e `post "a/tempo"`.
  - `SiteEventsController#whatsapp` registra `click_whatsapp` (com `cod_produto` opcional).
  - `SiteEventsController#tempo` atualiza `duracao_seg` do `view_produto` (valida 0..3600).
    SOMA ao valor existente (revisitas ao mesmo produto dentro de 30 min reaproveitam o
    mesmo evento) e só aceita se o evento pertencer ao visitante do cookie
    (`SiteAnalytics.visitor_atual(cookies) == evento.visitor_id`), para ninguém
    inflar o tempo de eventos alheios.
  - Tratar CSRF para `fetch`/`sendBeacon`.
  - _Requisitos: 3, 2_

- [x] 6. Front-end: clique de WhatsApp
  - No `_whatsapp_modal`, disparar `fetch("/a/whatsapp")` no clique, passando
    `cod_produto` quando houver, sem bloquear a abertura do link.
  - _Requisitos: 3_

- [x] 7. Front-end: tempo de permanência no produto
  - Em `produto.html.erb`, medir tempo com pausa no `visibilitychange`.
  - Enviar via `navigator.sendBeacon("/a/tempo", {evento_id, segundos})` no `pagehide`.
  - Só ativa quando há `@evento&.id`.
  - _Requisitos: 2_

- [x] 8. Relatório no backoffice
  - `Report::SiteAnalyticsController#index` com filtro de período (padrão 30 dias).
  - Agregações: totais (portfolio/produto/whatsapp), visitantes únicos, ranking
    de produtos (views + tempo médio + cliques whatsapp), por hora, por cidade
    (Brasil), por país e resumo Brasil × exterior, buscas mais feitas.
  - Rota `get "report_site_analytics"` no namespace `collaborators_backoffice`.
  - View seguindo o padrão de `collaborators_backoffice/report/`.
  - FUSO (corrigido): o app roda com `ENV['TZ'] = 'America/Sao_Paulo'`
    (`config/environment.rb`), `config.time_zone = 'America/Sao_Paulo'` e
    `default_timezone = :local` (`config/application.rb`). Logo `site_events.created_at`
    já guarda o horário de São Paulo "como está no relógio", em qualquer ambiente.
    Agrupar por hora/dia direto em SQL (`EXTRACT(HOUR FROM created_at)`), SEM converter
    fuso — converter de novo desloca 3 h. Filtros de período com `Time`/`Date` do Rails
    funcionam normalmente. (Uma versão anterior deste plano dizia que era UTC: estava errado.)
  - _Requisitos: 6 (todos os critérios), 7_

- [ ] 9. Testes
  - `SiteAnalytics`: dedupe 30 min, bot, visitor_id, normaliza_termo.
  - `GeoIpResolver`: sem base → `[nil,nil]`; com base → cidade/estado.
  - Controller público: responde :ok, sem auth, CSRF ok, valida duração.
  - Relatório: agregações por período corretas.
  - Garantir que o site renderiza com analytics falhando/desabilitado.
  - _Requisitos: todos_

- [ ] 10. Documentação de operação
  - Nota no README/docs sobre baixar a base `GeoLite2-City.mmdb` (conta MaxMind
    gratuita) e onde colocá-la (`db/geoip/`); comportamento quando ausente.
  - _Requisitos: 4_

- [ ] 11. Manter a base GeoLite atualizada (exigência da licença)
  - A licença do GeoLite exige apagar versões com mais de 30 dias de uma nova
    release (lançamentos toda terça e sexta). Baixar uma vez e esquecer descumpre
    a licença e reduz a precisão.
  - Automatizar com `geoipupdate` (usa Account ID + License Key, guardados em
    variável de ambiente/arquivo fora do repositório) agendado semanalmente, ou
    um rake task equivalente. O resolver já reabre o arquivo quando ele muda.
  - Limite da conta GeoLite: 30 downloads/dia.
  - _Requisitos: 4_

- [x] 12. Atribuição à MaxMind (exigência do contrato GeoLite, seção 3)
  - Exibir no relatório do backoffice (onde a cidade/estado aparece) o aviso:
    "This product includes GeoLite Data created by MaxMind, available from
    https://www.maxmind.com" (texto de exemplo do próprio contrato).
  - _Requisitos: 7_

## Decisões registradas durante a implementação
- Visitas do exterior guardam só o país (`pais` = código ISO, `pais_nome` = nome em
  pt-BR); cidade e estado ficam `nil`, pois a coluna `estado` guarda a UF brasileira
  e siglas de outros países seriam ambíguas (ex.: MA = Maranhão ou Massachusetts).
  O relatório agrupa pelo código (chave estável) e exibe o nome.
- A base (`db/geoip/*.mmdb`) está no `.gitignore` e não vai para o repositório
  (o contrato proíbe repassar o banco a terceiros sem consentimento da MaxMind).
- Contrato GeoLite (lido em 2026): permite uso para fins internos do negócio,
  exige atribuição, proíbe usar os dados para identificar pessoa/residência/endereço
  e exige atualizar a base e apagar versões antigas em até 30 dias.
- Gem `maxmind-db` fixada em 1.5.0.
- `SiteAnalytics` ignora também requisições HEAD e colaboradores/usuários LOGADOS no
  sistema (via Warden), para a equipe testando o site não inflar os números. Para
  testar manualmente, abrir o site em janela anônima/deslogado.
- Buscas com menos de 2 caracteres ou só símbolos não são gravadas; o termo é
  normalizado (minúsculo, sem acento, só `a-z0-9 . , / + -`, máx. 120).
- Em caso de dedupe, `track` devolve o evento já existente da janela (o beacon de
  tempo usa esse id). Cliques de WhatsApp nunca sofrem dedupe.
- Tarefa 3 verificada com 49 checagens em requisições simuladas (dedupe, expiração da
  janela, bots, WhatsApp, buscas, exterior, IP privado, robustez), dentro de transação
  com rollback.
- Tarefa 4 verificada ponta a ponta (36 checagens, requisições reais via sessão de
  integração): `view_portfolio`, `busca` e `view_produto` gravam uma vez por janela de
  30 min; bots, prévia do WhatsApp, produto inexistente e termos curtos não gravam;
  falha simulada no INSERT não derruba a página. Custo medido: ~3,7 ms por visita nova
  (consulta + GeoIP + INSERT) e ~0,9 ms por visita repetida.
- A home (`/`) NÃO é rastreada (escopo: portfólio, produto, busca e WhatsApp). Quem só
  vê a home não entra na contagem.
- Reiniciar o servidor de desenvolvimento após adicionar a gem `maxmind-db`; um
  servidor iniciado antes dela não resolve o país/cidade (grava em branco).
- O cookie `mr_vid` é um cookie próprio, anônimo e de estatística; vale citá-lo na
  política de privacidade do site.
- Tarefa 5: `SiteEventsController` herda de `ActionController::Base` (sem os filtros
  do ApplicationController) e usa `skip_forgery_protection`: sendBeacon não envia
  cabeçalhos, o token pode expirar com a página aberta e os endpoints só gravam
  evento anônimo. A autorização do `/a/tempo` é o cookie assinado do visitante.
  Responde sempre 204. Cliques com `cod_produto` inválido/inexistente são descartados.
- Tempo de permanência: soma atômica no SQL (`LEAST(COALESCE(duracao_seg,0)+n, 3600)`),
  aceita 1..3600 s por envio e limita o total do evento a 1 h (aba esquecida aberta
  distorceria a média). O JS (Tarefa 7) deve enviar o DELTA desde o último envio,
  não o total acumulado.
- `SiteAnalytics` agora converte `cod_produto` em base 10 (`Integer("010")` era 8).
- LIMITAÇÃO CONHECIDA: sem rate limit (o projeto não tem rack-attack e o Rails 7.1 não
  traz `rate_limit`). Quem enviar POSTs diretos pode inflar cliques de WhatsApp e
  crescer a tabela. Se virar problema: rack-attack limitando `/a/*` por IP.
- Tarefa 5 verificada com ~47 checagens HTTP reais (CSRF ativo no ambiente de teste).
- Tarefa 6: um único ouvinte no layout público (`click` + `auxclick` do botão do meio)
  registra qualquer link `a[href*="wa.me/"]` — modal de contatos, seção Equipe da home,
  ícone do rodapé, botão "WhatsApp" do telefone e botão flutuante. Só o modal informa o
  produto (`data-cod-produto`); os demais gravam clique sem produto. Usa
  `navigator.sendBeacon` (FormData) e cai para `fetch(keepalive)` se faltar; erros são
  engolidos e o clique nunca é impedido (sem `preventDefault`).
- Tarefa 6 verificada em Chrome real (headless, via DevTools Protocol) contra uma cópia
  do servidor: clique no modal (produto 15512), no ícone interno do botão flutuante,
  botão do meio e caminho sem sendBeacon geraram 4 cliques; botão direito, link do
  Facebook e âncora interna não geraram nada; 0 erros de JS; todos com o mesmo
  `visitor_id` do cookie.
- Tarefa 7: script em `home/produto.html.erb`, renderizado só se `@evento&.id` existir
  (nunca para bot, usuário logado no sistema ou produto inexistente). Conta apenas o
  tempo com a aba visível (`visibilitychange`), envia o DELTA por `sendBeacon` ao esconder
  a aba e no `pagehide`; `pageshow` com `persisted` retoma a contagem (cache voltar/avançar).
  Sem heartbeat periódico (não há requisições extras enquanto a pessoa lê).
  "Perder o foco" = aba/app em segundo plano; janela visível mas sem foco continua contando.
- Tarefa 7 verificada em Chrome real com relógio da página controlado (Date.now
  substituído): 3,4 s visível -> banco 3 s ao esconder a aba; 4 s escondida (não contou);
  +2,6 s visível e saída real da página -> banco 6 s (e não 10). 0 erros de JS. O
  esconder/mostrar da aba foi simulado (propriedade `visibilityState` + evento); o
  `pagehide` e os beacons são reais.
- Tarefa 8 (dashboard em página única): `CollaboratorsBackoffice::Report::RepSiteAnalyticsController`
  (nome no padrão `rep_*` do projeto; o plano dizia `SiteAnalyticsController`), serviço
  `SiteAnalyticsReport` (todas as agregações), views `report/rep_site_analytics/index` e
  `_kpi_card`. URL: `/collaborators_backoffice/report_site_analytics` (helper
  `collaborators_backoffice_report_site_analytics_path`). Período padrão: últimos 30 dias,
  atalhos 7/30/90 dias, datas inválidas/invertidas/futuras tratadas, máximo 366 dias.
- Conteúdo: 5 cartões com variação vs. período anterior de mesmo tamanho; visitas por dia
  (+ cliques de WhatsApp em eixo secundário); ranking de produtos (visualizações, tempo
  médio, cliques de WhatsApp, conversão); buscas com selo "sem produto" (quantos produtos
  o catálogo publicado acha HOJE, pela mesma busca do site); horário e dia da semana
  (pico destacado); cidades; Brasil × exterior e países; aviso quando há dados demo;
  atribuição à MaxMind (Tarefa 12). Chart.js 4.4.1 via CDN, como o dashboard fiscal; sem
  a biblioteca, os gráficos somem e as tabelas continuam.
- Permissão: recurso `report_site_analytics` ("Analytics do Site (Portfólio)") em
  `AccessRolePermission::AVAILABLE_RESOURCES` e em `ADMIN_ONLY_RESOURCES` (sem perfil de
  acesso, só admin vê; os demais via Perfis de Acesso). A checagem fica no próprio
  controller porque controllers de relatório não entram no `CONTROLLER_RESOURCE_MAP`
  (a URL direta ficaria aberta). NÃO foi criado link no menu (combinado: depois, em
  "Comunicação").
- `Produto.busca_texto(termo)` foi extraído do `HomeController#portfolio` e passou a ser
  usado também pelo relatório, para as duas telas nunca divergirem (comportamento do
  site verificado idêntico em 12 termos).
- Verificação: 21 checagens do serviço contra cálculo independente em Ruby (inclui hora
  SQL = hora Ruby em SP); ~45 checagens HTTP com login (sem login, admin, colaborador comum,
  filtros, período vazio, escape de HTML); Chrome real: 3 gráficos desenhados, 0 erros de
  JS, sem rolagem lateral em 1440 e 1024 px; capturas revisadas e 4 acertos visuais feitos
  (borda dos cartões, quebras de linha, curva da linha de cliques, subtítulo das cidades).
- LIMITAÇÃO: o layout do backoffice não tem `<meta name="viewport">`; no celular a página
  renderiza em ~980 px (desktop reduzido). O dashboard foi pensado para desktop/tablet e
  isso não foi tratado.
- Achado para o negócio: a busca do site compara a FRASE inteira ("mesa de jantar" não
  acha "Mesa Monaco"; "guarda roupa" não acha "guarda-roupa"). Melhorar a busca (casar por
  palavras/sinônimos) reduziria os "sem produto" que são, em parte, limitação da busca.
