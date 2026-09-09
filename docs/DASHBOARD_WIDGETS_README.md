# Dashboard de Widgets Configuráveis

Documentação do dashboard do backoffice (`collaborators_backoffice`), que substituiu o
dashboard fixo por um painel de **widgets configuráveis** por colaborador/empresa.

## Visão geral

Cada colaborador (por empresa) monta o próprio dashboard: liga/desliga widgets,
reordena por arrasto, e redimensiona **largura e altura** livremente. O conteúdo
de cada widget escala junto com o tamanho. A configuração é salva por
`cod_funcionario` + `cod_empresa`.

O painel fica em `GET /collaborators_backoffice/welcome/index` dentro de um card
"Dashboard". O botão **Configurar Widgets** aparece na navbar apenas nessa página.

## Arquitetura

| Camada | Arquivo |
|--------|---------|
| Model | `app/models/dashboard_widget.rb` |
| Dados dos widgets | `app/services/dashboard_data_service.rb` |
| Controller (config/API) | `app/controllers/collaborators_backoffice/dashboard_widgets_controller.rb` |
| Controller do dashboard | `app/controllers/collaborators_backoffice/welcome_controller.rb` |
| View principal | `app/views/collaborators_backoffice/welcome/index.html.erb` |
| Partials dos widgets | `app/views/collaborators_backoffice/welcome/widgets/_*.html.erb` |

### Tabela `dashboard_widgets`

Migrations: `create_dashboard_widgets`, `add_col_span_to_dashboard_widgets`,
`add_row_span_to_dashboard_widgets`.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `cod_funcionario` | bigint | Colaborador dono do layout |
| `cod_empresa` | bigint | Empresa (multi-tenant) |
| `widget_type` | string | Tipo do widget (chave do catálogo) |
| `position` | integer | Ordem no dashboard |
| `col_span` | integer | Largura em colunas do grid de 12 (1–12) |
| `row_span` | integer | Altura em unidades de ~90px (1–8) |
| `visible` | boolean | Se aparece no dashboard |
| `size` | string | Legado (não usado para largura) |
| `config` | jsonb | Reservado para configurações futuras |

Índice único por `(cod_funcionario, cod_empresa, widget_type)`.

## Catálogo de widgets (`DashboardWidget::CATALOG`)

Cada entrada define `label`, `resource` (recurso de controle de acesso; `nil` = sempre
visível), `default_span` (largura), `default_rows` (altura) e `default_visible`.

| widget_type | Rótulo | Recurso | Ligado por padrão |
|-------------|--------|---------|-------------------|
| `acesso_rapido` | Acesso Rápido (completo) | — | sim |
| `acesso_rapido_botoes` | Acesso Rápido (só botões) | — | não |
| `vendas_dia` | Vendas do Dia | vendas | não |
| `minhas_vendas` | Minhas Vendas (Mês) | vendas | não |
| `vendas_empresa` | Total Vendas Empresa (Mês) | vendas | não |
| `caixa` | Caixa | caixa | sim |
| `financeiro` | Resumo Financeiro (Mês) | contas_pag_rec | sim |
| `estoque_minimo` | Estoque Mínimo Atingido | empresa_estoque | sim |
| `top_produtos` | Produtos Mais Vendidos (Mês) | vendas | sim |
| `atendimentos` | Atendimentos | atendimentos | não |
| `vendas_custo` | Receita x Custo (6 meses) | report_rep_dre | não |
| `comissoes` | Minhas Comissões | commission_periods | não |
| `aniversariantes` | Aniversariantes da Semana | report_aniversariantes | não |

O **layout padrão** (para usuários novos ou ao "Restaurar padrão") reproduz o
dashboard antigo: Acesso Rápido + Estoque Mínimo + Top Produtos + Caixa +
Resumo Financeiro ligados; o restante disponível, porém desligado.

### Controle de acesso

Cada widget mapeia um recurso do `AccessControlService`. Um widget só é exibido
(e listado na configuração) se `access_control.can_view?(resource)` for verdadeiro.
Assim, por exemplo, o widget de Caixa não aparece para quem não tem permissão de caixa.

## Comportamento do layout

- **Ligar/desligar**: pelo modal "Configurar Widgets" ou pelo botão **X** no canto de
  cada widget (desliga na hora).
- **Reordenar**: arrastar pelo ícone de "grip" (SortableJS). A nova ordem é salva.
- **Redimensionar**: por arrasto direto no widget —
  - borda direita → largura (`col_span`, 1–12);
  - borda inferior → altura (`row_span`, 1–8);
  - canto inferior-direito → largura e altura juntas.
  Também há sliders de Largura e Altura no modal de configuração.
- **Sync incremental**: ao abrir o dashboard, widgets novos do catálogo são
  adicionados ao layout existente sem alterar o que já estava configurado.
- **Restaurar padrão**: recria o layout padrão (perde a personalização atual).

## Conteúdo responsivo (escala com o tamanho)

O conteúdo acompanha o tamanho do widget via **CSS container queries**:

- Cada widget é um container (`.widget-box` com `container-type: size`).
- A fonte-base do card escala pelo tamanho do container
  (`clamp(0.55rem, 0.4rem + 1.2cqw + 1.2cqh, 1.1rem)`); como o conteúdo usa `em`,
  tudo escala junto.
- **Métricas grandes** (`.widget-metric-big`) em Vendas do Dia, Minhas Vendas e
  Total Vendas crescem bastante com o widget (até ~5rem) — ideal para "deixar
  grande e acompanhar a meta".
- **Widgets de lista** (`aniversariantes`, `atendimentos`, `top_produtos`,
  `estoque_minimo`): a área de conteúdo tem **scroll interno** (`.widget-scroll`)
  e preenche a altura do card, mostrando todos os itens.
- **Widgets de grade** (`caixa`, `financeiro`, `comissoes`): as "caixinhas"
  **encolhem para caber** na altura (`.widget-fill`), sem scroll.

## Widgets de dados (fonte)

Os dados são calculados sob demanda em `DashboardDataService`, apenas para os
widgets ativos. Todos escopados por `cod_empresa`.

- **vendas_dia / minhas_vendas / vendas_empresa**: somas de `Venda` (tipo `V`, não
  cancelada) no dia/mês.
- **caixa**: caixa aberto (`Caixa` sem `datafechamento`) e último fechamento.
- **financeiro**: minhas vendas, total vendas, e `Contaspagrec` a pagar/receber do mês.
- **estoque_minimo**: SQL agregando `empresaproduto` com quantidade mínima atingida.
- **top_produtos**: `Itemvenda` agrupado por produto no mês.
- **atendimentos**: contadores do dia + lista de retornos pendentes (`Atendimento`).
- **vendas_custo**: receita x custo dos últimos 6 meses (mesma lógica do DRE), via Chart.js.
- **comissoes**: último período de comissão do colaborador (`CommissionPeriod`).
- **aniversariantes**: clientes com compra na loja e aniversário nos próximos 7 dias.

## Relatório de Aniversariantes

Complementa o widget `aniversariantes`.

- Rota: `GET /collaborators_backoffice/report_aniversariantes`
  (`collaborators_backoffice_report_aniversariantes_path`).
- Controller: `app/controllers/collaborators_backoffice/report/rep_aniversariantes_controller.rb`.
- View: `app/views/collaborators_backoffice/report/rep_aniversariantes/index.html.erb`.
- Filtro: clientes com compra na empresa logada; período por dia/mês do aniversário
  (padrão: hoje até o fim do mês; trata virada de ano).
- Colunas: nome, telefone/celular (com link WhatsApp), aniversário, nº de compras
  (link para o histórico de vendas do cliente), última compra e situação
  (badge "Em aberto: R$ X" ou "Em dia").
- Recurso de acesso: `report_aniversariantes` (em `AccessRolePermission::AVAILABLE_RESOURCES`),
  com link no menu lateral em Relatórios.

## Endpoints (JSON)

Controller `DashboardWidgetsController`:

| Método | Rota | Ação |
|--------|------|------|
| GET | `dashboard_widgets` | Lista widgets do colaborador (id, tipo, label, col_span, row_span, visible, position) |
| PATCH | `dashboard_widgets/:id` | Atualiza `visible`, `col_span` e/ou `row_span` (com clamp) |
| PATCH | `dashboard_widgets/reorder` | Persiste a nova ordem (array de ids) |
| POST | `dashboard_widgets/reset` | Remove o layout e recria o padrão |

## Como adicionar um novo widget

1. Adicionar a entrada no `CATALOG` do `DashboardWidget` (label, resource, default_span,
   default_rows, default_visible) e em `COLORS`; incluir no `DEFAULT_LAYOUT`.
2. Se for de lista, incluir em `LIST_WIDGETS`.
3. Adicionar o cálculo dos dados no `DashboardDataService` (dispatch em `compute` + método).
4. Criar a partial `app/views/collaborators_backoffice/welcome/widgets/_<tipo>.html.erb`
   (recebe `cor` e `span` como locals).
5. Se depender de um recurso novo, garantir a chave em `AVAILABLE_RESOURCES`.

Dependências externas via CDN: **SortableJS** (reordenar) e **Chart.js** (gráfico).
Container queries exigem navegador moderno; em navegadores antigos o conteúdo
apenas não escala (não quebra).
