class CollaboratorPermission < ApplicationRecord
  # Validações
  validates :cod_funcionario, presence: true
  validates :cod_empresa, presence: true
  validates :resource, presence: true
  validates :resource, uniqueness: {
    scope: [:cod_funcionario, :cod_empresa],
    message: 'já possui uma permissão individual para este recurso'
  }

  # Scopes
  scope :for_funcionario, ->(cod_funcionario) { where(cod_funcionario: cod_funcionario) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :viewable, -> { where(can_view: true) }

  # Consultas a entidades existentes (somente leitura)
  def funcionario
    Funcionario.find_by(cod_funcionario: cod_funcionario)
  end

  def funcionario_nome
    func = funcionario
    func&.pessoa_nome || func&.usuario
  end

  def resource_label
    AccessRolePermission::AVAILABLE_RESOURCES[resource] || resource.humanize
  end
end
