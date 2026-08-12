class CollaboratorAccessRole < ApplicationRecord
  belongs_to :access_role

  # Validações
  validates :cod_funcionario, presence: true
  validates :cod_empresa, presence: true
  validates :cod_funcionario, uniqueness: {
    scope: :cod_empresa,
    message: 'já possui um perfil atribuído nesta empresa'
  }

  # Scopes
  scope :for_funcionario, ->(cod_funcionario) { where(cod_funcionario: cod_funcionario) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }

  # Consultas a entidades existentes (somente leitura)
  def funcionario
    Funcionario.find_by(cod_funcionario: cod_funcionario)
  end

  def funcionario_nome
    func = funcionario
    func&.pessoa_nome || func&.usuario
  end

  def empresa
    Empresa.find_by(cod_empresa: cod_empresa)
  end
end
