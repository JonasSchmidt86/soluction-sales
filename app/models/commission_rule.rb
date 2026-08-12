class CommissionRule < ApplicationRecord
  # Relacionamentos internos do módulo
  has_many :commission_tiers, -> { order(:position) }, dependent: :destroy
  has_many :commission_assignments, dependent: :restrict_with_error
  has_many :commission_periods

  accepts_nested_attributes_for :commission_tiers, allow_destroy: true, reject_if: :all_blank

  # Validações
  validates :name, presence: true
  validates :name, uniqueness: { scope: :cod_empresa }
  validates :cod_empresa, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }

  # Métodos de consulta a entidades existentes (somente leitura)
  def empresa
    Empresa.find_by(cod_empresa: cod_empresa)
  end

  def empresa_nome
    Empresa.where(cod_empresa: cod_empresa).pluck(:nome).first
  end

  # Vendedores atualmente atribuídos a esta regra
  def current_assignments
    commission_assignments.where(end_date: nil)
  end

  def assigned_funcionarios
    cod_funcionarios = current_assignments.pluck(:cod_funcionario)
    Funcionario.where(cod_funcionario: cod_funcionarios)
  end
end
