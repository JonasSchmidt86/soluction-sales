class DashboardWidget < ApplicationRecord
  MIN_SPAN = 1
  MAX_SPAN = 12

  # Altura em "unidades" de grade e a altura em pixels de cada unidade.
  MIN_ROWS = 1
  MAX_ROWS = 8
  ROW_UNIT_PX = 90

  # Catálogo de widgets disponíveis.
  # Cada entrada define: label (exibição), resource (recurso do controle de acesso
  # necessário para ver o widget; nil = sempre visível), largura padrão em colunas
  # (grid de 12) e visibilidade padrão.
  # default_visible: true para os widgets que já existiam no dashboard antigo
  # (Acesso Rápido completo, Estoque Mínimo, Top Produtos, Caixa e Resumo
  # Financeiro). Os demais ficam disponíveis, porém desligados por padrão.
  CATALOG = {
    'acesso_rapido'         => { label: 'Acesso Rápido (completo)',  resource: nil,                  default_span: 12, default_rows: 5, default_visible: true },
    'acesso_rapido_botoes'  => { label: 'Acesso Rápido (só botões)', resource: nil,                  default_span: 12, default_rows: 2, default_visible: false },
    'vendas_dia'      => { label: 'Vendas do Dia (minhas)',   resource: 'vendas',            default_span: 4,  default_rows: 2, default_visible: false },
    'vendas_dia_empresa' => { label: 'Vendas do Dia (empresa)', resource: 'report_rep_dre',  default_span: 4,  default_rows: 2, default_visible: false },
    'minhas_vendas'   => { label: 'Minhas Vendas (Mês)',      resource: 'vendas',            default_span: 4,  default_rows: 2, default_visible: false },
    'vendas_empresa'  => { label: 'Total Vendas Empresa (Mês)', resource: 'vendas',          default_span: 4,  default_rows: 2, default_visible: false },
    'caixa'           => { label: 'Caixa',                    resource: 'caixa',             default_span: 6,  default_rows: 3, default_visible: true },
    'financeiro'      => { label: 'Resumo Financeiro (Mês)',  resource: 'contas_pag_rec',    default_span: 6,  default_rows: 3, default_visible: true },
    'estoque_minimo'  => { label: 'Estoque Mínimo Atingido',  resource: 'empresa_estoque',   default_span: 6,  default_rows: 4, default_visible: true },
    'top_produtos'    => { label: 'Top Produtos (Mês)',       resource: 'vendas',            default_span: 6,  default_rows: 4, default_visible: true },
    'atendimentos'    => { label: 'Atendimentos',             resource: 'atendimentos',      default_span: 6,  default_rows: 4, default_visible: false },
    'vendas_custo'    => { label: 'Receita x Custo (6 meses)', resource: 'report_rep_dre',   default_span: 12, default_rows: 4, default_visible: false },
    'comissoes'       => { label: 'Minhas Comissões',         resource: 'commission_periods', default_span: 6, default_rows: 3, default_visible: false },
    'aniversariantes' => { label: 'Aniversariantes da Semana', resource: 'report_aniversariantes', default_span: 6, default_rows: 4, default_visible: false }
  }.freeze

  WIDGET_TYPES = CATALOG.keys.freeze
  SIZES = %w[sm md lg].freeze

  # Widgets criados por padrão para quem ainda não configurou o dashboard,
  # na ordem em que aparecem.
  # Ordem do layout. Os primeiros reproduzem o dashboard antigo (ligados por
  # padrão); os demais vêm depois, desligados, disponíveis para ativar.
  DEFAULT_LAYOUT = %w[
    acesso_rapido
    estoque_minimo
    top_produtos
    caixa
    financeiro
    acesso_rapido_botoes
    vendas_dia
    vendas_dia_empresa
    minhas_vendas
    vendas_empresa
    atendimentos
    vendas_custo
    comissoes
    aniversariantes
  ].freeze

  # Cor de destaque (borda) de cada widget, no padrão dos cards do Acesso Rápido.
  COLORS = {
    'acesso_rapido'        => 'primary',
    'acesso_rapido_botoes' => 'primary',
    'vendas_dia'           => 'primary',
    'vendas_dia_empresa'   => 'primary',
    'minhas_vendas'        => 'success',
    'vendas_empresa'       => 'success',
    'caixa'                => 'info',
    'financeiro'           => 'warning',
    'estoque_minimo'       => 'danger',
    'top_produtos'         => 'success',
    'atendimentos'         => 'success',
    'vendas_custo'         => 'info',
    'comissoes'            => 'warning',
    'aniversariantes'      => 'danger'
  }.freeze

  # Validações
  validates :cod_funcionario, presence: true
  validates :cod_empresa, presence: true
  validates :widget_type, presence: true, inclusion: { in: WIDGET_TYPES }
  validates :col_span, numericality: { only_integer: true, greater_than_or_equal_to: MIN_SPAN, less_than_or_equal_to: MAX_SPAN }
  validates :row_span, numericality: { only_integer: true, greater_than_or_equal_to: MIN_ROWS, less_than_or_equal_to: MAX_ROWS }
  validates :widget_type, uniqueness: {
    scope: [:cod_funcionario],
    message: 'já está no dashboard'
  }

  # Scopes
  scope :for_funcionario, ->(cod_funcionario) { where(cod_funcionario: cod_funcionario) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }
  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }

  # Visibilidade padrão de um widget (usada ao criar/sincronizar o layout).
  def self.default_visible_for(type)
    CATALOG.dig(type, :default_visible) != false
  end

  # Largura padrão (em colunas) de um widget.
  def self.default_span_for(type)
    CATALOG.dig(type, :default_span) || 6
  end

  # Altura padrão (em unidades de grade) de um widget.
  def self.default_rows_for(type)
    CATALOG.dig(type, :default_rows) || 3
  end

  # Recurso do controle de acesso associado a este widget (nil = sempre visível).
  def resource
    CATALOG.dig(widget_type, :resource)
  end

  # Cor (contexto Bootstrap) usada na borda do widget.
  def color
    COLORS[widget_type] || 'secondary'
  end

  def label
    CATALOG.dig(widget_type, :label) || widget_type.humanize
  end

  # Widgets cujo conteúdo é uma lista/tabela com rolagem interna. Recebem a
  # classe .widget-list para que a área de scroll preencha a altura do card.
  LIST_WIDGETS = %w[aniversariantes atendimentos top_produtos estoque_minimo].freeze

  def list?
    LIST_WIDGETS.include?(widget_type)
  end

  # Largura efetiva em colunas, sempre dentro dos limites.
  def span
    (col_span || self.class.default_span_for(widget_type)).clamp(MIN_SPAN, MAX_SPAN)
  end

  # Altura efetiva em unidades de grade, sempre dentro dos limites.
  def rows
    (row_span || self.class.default_rows_for(widget_type)).clamp(MIN_ROWS, MAX_ROWS)
  end

  # Altura efetiva em pixels.
  def height_px
    rows * ROW_UNIT_PX
  end

  # Retorna o layout do colaborador (ÚNICO por usuário, independente de empresa),
  # criando o layout padrão na primeira vez e completando com widgets novos do
  # catálogo que ainda não existam (sync incremental, sem perder a config atual).
  #
  # `cod_empresa` é usado apenas para preencher a coluna na criação de novos
  # registros (referência de origem); NÃO faz parte da chave de busca.
  def self.layout_for(cod_funcionario, cod_empresa = nil)
    scope = for_funcionario(cod_funcionario)
    if scope.none?
      ensure_defaults!(cod_funcionario, cod_empresa)
    else
      sync_new_widgets!(cod_funcionario, cod_empresa, scope)
    end
    scope.ordered
  end

  # Cria os widgets padrão para um colaborador que ainda não tem layout.
  def self.ensure_defaults!(cod_funcionario, cod_empresa = nil)
    DEFAULT_LAYOUT.each_with_index do |type, index|
      find_or_create_by(cod_funcionario: cod_funcionario, widget_type: type) do |w|
        w.cod_empresa = cod_empresa
        w.position = index
        w.col_span = default_span_for(type)
        w.row_span = default_rows_for(type)
        w.visible = default_visible_for(type)
      end
    end
  end

  # Adiciona ao layout existente os widgets do catálogo que ainda não foram
  # criados para o colaborador, sem alterar os já configurados. Os novos
  # entram no fim (após a maior posição atual).
  def self.sync_new_widgets!(cod_funcionario, cod_empresa, scope)
    existentes = scope.pluck(:widget_type)
    faltando = DEFAULT_LAYOUT - existentes
    return if faltando.empty?

    # Empresa de referência para novos registros (usa a já existente se houver)
    empresa_ref = cod_empresa || scope.first&.cod_empresa

    proxima_posicao = (scope.maximum(:position) || -1) + 1
    faltando.each_with_index do |type, i|
      find_or_create_by(cod_funcionario: cod_funcionario, widget_type: type) do |w|
        w.cod_empresa = empresa_ref
        w.position = proxima_posicao + i
        w.col_span = default_span_for(type)
        w.row_span = default_rows_for(type)
        w.visible = default_visible_for(type)
      end
    end
  end
end
