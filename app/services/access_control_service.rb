# Serviço responsável pela verificação de permissões de acesso.
#
# Regra de fallback (opt-in):
#   Se o colaborador NÃO tem grupo atribuído E NÃO tem override individual:
#     → comportamento legado (permissao.nivel == 1 vê tudo, demais não veem recursos admin-only)
#   Se TEM grupo ou override:
#     → aplica as novas regras de acesso
#
# Prioridade:
#   1. Override individual (collaborator_permissions) — prevalece sempre
#   2. Permissão do grupo (access_role_permissions via collaborator_access_roles)
#   3. Fallback — comportamento legado
#
class AccessControlService
  attr_reader :cod_funcionario, :cod_empresa, :permissao_nivel

  # Recursos que no sistema original eram restritos a nivel == 1 (admin).
  # No fallback (sem perfil), esses recursos ficam bloqueados para não-admin.
  ADMIN_ONLY_RESOURCES = %w[
    provisionados
    report_rep_dre
    report_custom_reports
    acertosestoque
    funcionarios
    collaborators
    access_roles
    commission_rules
    commission_assignments
    commission_adjustments
    commission_periods
    xml_files
    compras
    report_buy
    report_sugestao_compra
    pedidos_compras
    whatsapp_contacts
  ].freeze

  # Recursos em desenvolvimento/teste — visíveis SOMENTE para super_admin (cod_funcionario == 1).
  # Use para subir features novas para produção sem que outros vejam.
  # Quando estiver pronto, remova o recurso desta lista.
  SUPER_ADMIN_ONLY_RESOURCES = %w[
    commission_rules
    commission_assignments
    commission_periods
    commission_adjustments
    report_custom_reports
  ].freeze

  def initialize(collaborator)
    @cod_funcionario = collaborator.cod_funcionario
    @cod_empresa = collaborator.cod_empresa
    @permissao_nivel = collaborator.funcionario&.permissao&.nivel
    @role_assignment = nil
    @loaded = false
  end

  # Verifica se o colaborador pode executar uma ação em um recurso.
  #
  # @param action [Symbol] :view, :create, :edit, :delete
  # @param resource [String] nome do recurso (ex: 'vendas', 'commission_periods')
  # @return [Boolean]
  def can?(action, resource)

    # Se não está sob controle de acesso, comportamento legado
    unless under_access_control?
      # No legado, recursos admin-only ficam bloqueados para não-admin
      return false if ADMIN_ONLY_RESOURCES.include?(resource)
      return true
    end
    
    # Recursos super_admin_only: só super_admin (cod_funcionario == 1, nivel == 1) pode ver
    if SUPER_ADMIN_ONLY_RESOURCES.include?(resource)
      return super_admin?
    end

    # Admin (nivel 1) sempre pode tudo
    return true if admin?

    # 1. Verificar override individual
    individual = individual_permission(resource)
    if individual
      return individual.send("can_#{action}")
    end

    # 2. Verificar permissão do grupo
    role_perm = role_permission(resource)
    if role_perm
      return role_perm.send("can_#{action}")
    end

    # 3. Recurso não está no grupo nem no override → acesso negado
    false
  end

  # Verifica se o colaborador pode visualizar um recurso (atalho).
  def can_view?(resource)
    can?(:view, resource)
  end

  def can_create?(resource)
    can?(:create, resource)
  end

  def can_edit?(resource)
    can?(:edit, resource)
  end

  def can_delete?(resource)
    can?(:delete, resource)
  end

  # Retorna true se o colaborador está sob controle de acesso
  # (tem grupo atribuído OU tem pelo menos um override individual).
  def under_access_control?
    load_data!
    @under_control
  end

  # Retorna todos os recursos que o colaborador pode visualizar.
  # Usado para montar o menu lateral.
  def viewable_resources
    # Super admin vê tudo
    return AccessRolePermission::AVAILABLE_RESOURCES.keys if super_admin?

    # Admin vê tudo exceto super_admin_only
    if admin?
      return AccessRolePermission::AVAILABLE_RESOURCES.keys.reject { |r| SUPER_ADMIN_ONLY_RESOURCES.include?(r) }
    end

    # Se não está sob controle, comportamento legado (tudo exceto admin-only e super-admin-only)
    unless under_access_control?
      return AccessRolePermission::AVAILABLE_RESOURCES.keys.reject { |r|
        ADMIN_ONLY_RESOURCES.include?(r) || SUPER_ADMIN_ONLY_RESOURCES.include?(r)
      }
    end

    resources = Set.new

    # Recursos do grupo
    if role_assignment
      role_assignment.access_role.access_role_permissions.viewable.each do |perm|
        resources.add(perm.resource)
      end
    end

    # Overrides individuais (adiciona os que têm can_view)
    individual_permissions.each do |perm|
      if perm.can_view
        resources.add(perm.resource)
      else
        resources.delete(perm.resource)
      end
    end

    resources.to_a
  end

  # Verifica se é admin (nivel 1)
  def admin?
    @permissao_nivel == 1
  end

  # Verifica se é super admin (nivel 1 E cod_funcionario == 1)
  def super_admin?
    @permissao_nivel == 1 && @cod_funcionario == 1
  end

  private

  def load_data!
    return if @loaded

    @role_assignment = CollaboratorAccessRole
      .for_funcionario(@cod_funcionario)
      .for_empresa(@cod_empresa)
      .includes(access_role: :access_role_permissions)
      .first

    @individual_permissions = CollaboratorPermission
      .for_funcionario(@cod_funcionario)
      .for_empresa(@cod_empresa)
      .to_a

    @under_control = @role_assignment.present? || @individual_permissions.any?
    @loaded = true
  end

  def role_assignment
    load_data!
    @role_assignment
  end

  def individual_permissions
    load_data!
    @individual_permissions
  end

  def individual_permission(resource)
    individual_permissions.find { |p| p.resource == resource }
  end

  def role_permission(resource)
    return nil unless role_assignment
    role_assignment.access_role.access_role_permissions.find { |p| p.resource == resource }
  end
end
