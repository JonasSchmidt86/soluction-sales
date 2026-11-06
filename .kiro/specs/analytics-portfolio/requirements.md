# Requisitos — Analytics do Portfólio Público

## Introdução

Este recurso adiciona um contador de acessos e interações ao site público de
catálogo (moveisrosa.shop). O objetivo é entender o comportamento dos **clientes**
(não dos colaboradores que usam o ERP), medindo:

- Quantas **pessoas únicas** acessam o portfólio e as fotos dos produtos.
- Quais **produtos** são mais visualizados (ranking).
- Quantas vezes o **link do WhatsApp** é aberto.
- Em quais **horários** há mais acesso.
- De quais **cidades** vêm os acessos (estimado por IP via base GeoIP local).

O rastreamento ocorre apenas nas páginas públicas (`home#portfolio`,
`home#produto`) e no clique do modal de WhatsApp. O backoffice (ERP) não é
rastreado, o que naturalmente exclui os colaboradores.

## Decisões fechadas com o cliente

- **Visitante único:** identificado por um cookie anônimo (ID aleatório), sem login.
- **Ranking:** por **produto** (agregando as cores), guardando qual produto foi visto/clicado.
- **Evento guarda:** tipo, produto (sem cor), data/hora, país, cidade/estado (só
  Brasil), id anônimo.
- **Geolocalização:** base GeoIP **local** (MaxMind GeoLite2). Resolve a localização
  no momento do registro e **grava país e, para o Brasil, cidade/estado** — o IP
  não é persistido. Visitas do exterior guardam só o país.
- **Bots:** acessos de crawlers conhecidos (Google, Bing, etc.) são descartados.
- **Tela:** relatório no backoffice (futuramente no menu "Comunicação").
- **Janela de sessão:** 30 minutos. Uma mesma pessoa (mesmo cookie) navegando no
  portfólio dentro de 30 min conta como **uma única visita**. A mesma view de
  produto pela mesma pessoa dentro de 30 min também não é recontada (dedupe).
- **Tempo de permanência:** medido no navegador e enviado em segundo plano
  (`navigator.sendBeacon`), sem atrasar o carregamento nem travar a saída da
  página. A contagem pausa quando a aba perde o foco, para não inflar o tempo.

## Requisitos

### Requisito 1 — Registrar visita ao portfólio

**User Story:** Como gestor, quero saber quantas pessoas acessam o portfólio,
para medir o alcance do catálogo.

#### Acceptance Criteria
1. WHEN um visitante carrega a página do portfólio AND não houve visita do mesmo
   id anônimo nos últimos 30 minutos THEN o sistema SHALL registrar um evento
   `view_portfolio` com data/hora e o id anônimo do visitante.
2. WHEN o mesmo visitante recarrega, filtra ou pagina o portfólio dentro de 30
   minutos THEN o sistema SHALL NOT registrar uma nova visita (conta como a mesma).
3. IF a requisição for identificada como bot THEN o sistema SHALL NOT registrar o evento.
4. WHEN o visitante não possui cookie anônimo THEN o sistema SHALL criar um id
   anônimo e gravá-lo em cookie de longa duração.

### Requisito 2 — Registrar visualização de produto

**User Story:** Como gestor, quero saber quais produtos têm as fotos mais
visualizadas, para priorizar divulgação e estoque.

#### Acceptance Criteria
1. WHEN um visitante abre a página de detalhes de um produto AND o mesmo id
   anônimo não viu esse produto nos últimos 30 minutos THEN o sistema SHALL
   registrar um evento `view_produto` com o `cod_produto`, data/hora e id anônimo.
2. The system SHALL associar o evento ao produto (sem cor) para o ranking.
3. IF a requisição for bot THEN o sistema SHALL NOT registrar o evento.
4. WHEN o visitante sai da página do produto THEN o navegador SHALL enviar, em
   segundo plano (`navigator.sendBeacon`), o tempo de permanência para atualizar
   o evento `view_produto` correspondente, sem atrasar o carregamento nem a saída.
5. WHEN a aba perde o foco THEN a contagem de tempo SHALL pausar, retomando ao
   voltar o foco, para não inflar a permanência.

### Requisito 3 — Registrar clique no WhatsApp

**User Story:** Como gestor, quero saber quantas vezes o link do WhatsApp é
aberto e a partir de qual produto, para medir intenção de contato.

#### Acceptance Criteria
1. WHEN o visitante clica em um contato do WhatsApp no modal THEN o sistema SHALL
   registrar um evento `click_whatsapp` antes de abrir o link, sem impedir a abertura.
2. IF o clique veio da página de um produto THEN o evento SHALL incluir o `cod_produto`.
3. WHEN o registro falhar (erro de rede/servidor) THEN o link do WhatsApp SHALL
   abrir normalmente mesmo assim (o rastreamento não bloqueia a ação).

### Requisito 4 — Visitante único e geolocalização

**User Story:** Como gestor, quero distinguir pessoas de acessos e saber a cidade
aproximada, para entender o público.

#### Acceptance Criteria
1. The system SHALL identificar o visitante por um id anônimo persistido em cookie.
2. WHEN um evento é registrado THEN o sistema SHALL resolver o país a partir do IP
   usando a base GeoLite2 local e, quando o país for o Brasil, também cidade/estado;
   SHALL gravar apenas esses dados.
3. IF o IP não for resolvível THEN o sistema SHALL gravar país, cidade e estado em
   branco sem falhar o registro.
4. The system SHALL NOT persistir o endereço IP do visitante.

### Requisito 5 — Filtrar bots

**User Story:** Como gestor, quero que crawlers não inflem os números, para ter
dados confiáveis.

#### Acceptance Criteria
1. WHEN o user-agent corresponder a um padrão conhecido de bot THEN o sistema
   SHALL descartar o evento.
2. The system SHALL NOT persistir o user-agent (usado apenas para a decisão).

### Requisito 6 — Registrar buscas feitas

**User Story:** Como gestor, quero saber o que os clientes mais procuram no
portfólio, para identificar demanda e oportunidades (inclusive itens que não
temos cadastrados).

#### Acceptance Criteria
1. WHEN o portfólio é carregado com um termo de busca preenchido THEN o sistema
   SHALL registrar um evento `busca` com o termo digitado, data/hora e id anônimo.
2. The system SHALL normalizar o termo (minúsculo, sem acento, espaços aparados)
   para agrupar variações como o mesmo no ranking.
3. WHEN o mesmo visitante repete a mesma busca (termo normalizado) dentro de 30
   minutos THEN o sistema SHALL NOT registrar novamente (dedupe).
4. IF a requisição for bot THEN o sistema SHALL NOT registrar o evento.

### Requisito 7 — Relatório no backoffice

**User Story:** Como gestor, quero visualizar os números num relatório filtrável
por período, para acompanhar a evolução.

#### Acceptance Criteria
1. The system SHALL exibir, para um período selecionado: total de visitas ao
   portfólio, total de visualizações de produto, nº de visitantes únicos e total
   de cliques no WhatsApp.
2. The system SHALL exibir o ranking dos produtos mais visualizados no período,
   com o tempo médio de permanência por produto.
3. The system SHALL exibir a distribuição de acessos por horário do dia.
4. The system SHALL exibir a distribuição de acessos por cidade/estado (Brasil), por
   país e o resumo Brasil × exterior.
5. The system SHALL exibir o ranking das buscas mais feitas (termo normalizado e
   quantidade) no período.
6. WHEN nenhum período é informado THEN o relatório SHALL usar um intervalo padrão
   (ex.: últimos 30 dias).
7. The report SHALL respeitar o controle de acesso do backoffice (somente
   colaboradores autorizados).
