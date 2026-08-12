class AccessRole < ApplicationRecord
  has_many :access_role_permissions, dependent: :destroy
  has_many :collaborator_access_roles, dependent: :restrict_with_error

  accepts_nested_attributes_for :access_role_permissions, allow_destroy: true, reject_if: :all_blank

  # Validações
  validates :name, presence: true
  validates :name, uniqueness: { scope: :cod_empresa }
  validates :cod_empresa, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }

  # Consultas a entidades existentes (somente leitura)
  def empresa
    Empresa.find_by(cod_empresa: cod_empresa)
  end

  def empresa_nome
    Empresa.where(cod_empresa: cod_empresa).pluck(:nome).first
  end

  # Retorna os funcionários atribuídos a este grupo
  def assigned_funcionarios
    cod_funcionarios = collaborator_access_roles.pluck(:cod_funcionario)
    Funcionario.where(cod_funcionario: cod_funcionarios)
  end

  # Verifica permissão de um recurso específico
  def can?(action, resource)
    perm = access_role_permissions.find_by(resource: resource)
    return false unless perm
    perm.send("can_#{action}")
  end
end
