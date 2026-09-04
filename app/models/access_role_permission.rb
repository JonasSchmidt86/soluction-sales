class AccessRolePermission < ApplicationRecord
  belongs_to :access_role

  # Validações
  validates :resource, presence: true
  validates :resource, uniqueness: { scope: :access_role_id,
    message: 'já cadastrado para este perfil' }

  # Scopes
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :viewable, -> { where(can_view: true) }

  # Lista de recursos disponíveis no sistema
  AVAILABLE_RESOURCES = {
    'welcome' => 'Dashboard',
    'caixa' => 'Caixa',
    'vendas' => 'Vendas',
    'orcamentos' => 'Orçamentos',
    'contas_pag_rec' => 'Contas Pagar/Receber',
    'produtos' => 'Produtos',
    'pessoas' => 'Pessoas',
    'funcionarios' => 'Funcionários',
    'collaborators' => 'Colaboradores',
    'compras' => 'Compras',
    'pedidos_compras' => 'Pedidos de Compra',
    'empresa_estoque' => 'Estoque',
    'acertosestoque' => 'Acertos de Estoque',
    'lancamentosdiversos' => 'Provisionados',
    'lancamentoscaixas' => 'Lançamentos Caixa',
    'cores' => 'Cores',
    'marcas' => 'Marcas',
    'grupos' => 'Grupos',
    'produto_imagens' => 'Imagens de Produtos',
    'melhorias' => 'Melhorias/Sugestões',
    'commission_rules' => 'Comissões - Regras',
    'commission_assignments' => 'Comissões - Atribuições',
    'commission_periods' => 'Comissões - Apurações',
    'commission_adjustments' => 'Comissões - Ajustes',
    'report_sales' => 'Relatório de Vendas',
    'report_buy' => 'Relatório de Compras',
    'report_put_box' => 'Lançamentos Caixa (Relatório)',
    'report_stock_min' => 'Estoque Mínimo',
    'report_mais_vendidos' => 'Produtos Mais Vendidos',
    'report_rep_dre' => 'DRE',
    'report_custom_reports' => 'Outros Relatórios',
    'report_sugestao_compra' => 'Sugestão de Compra',
    'atendimentos' => 'Atendimentos',
    'notas_fiscais' => 'Notas Fiscais',
    'xml_files' => 'XML',
    'whatsapp_contacts' => 'WhatsApp',
    'access_roles' => 'Perfis de Acesso',
    'lembretes' => 'Lembretes'
  }.freeze

  def resource_label
    AVAILABLE_RESOURCES[resource] || resource.humanize
  end
end
