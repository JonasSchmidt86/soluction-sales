class CommissionAdjustment < ApplicationRecord
  # Relacionamentos internos
  belongs_to :commission_period, optional: true
  belongs_to :applied_in_period, class_name: 'CommissionPeriod',
             foreign_key: :applied_in_period_id, optional: true

  # Validações
  validates :cod_funcionario, presence: true
  validates :cod_empresa, presence: true
  validates :adjustment_type, presence: true, inclusion: {
    in: %w[cancelled_sale manual sale_change]
  }
  validates :direction, presence: true, inclusion: { in: %w[debit credit] }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending applied cancelled] }
  validates :cod_venda, uniqueness: {
    scope: [:commission_period_id, :adjustment_type],
    message: 'já possui um ajuste deste tipo para esta comissão'
  }, allow_nil: true

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :applied, -> { where(status: 'applied') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :debits, -> { where(direction: 'debit') }
  scope :credits, -> { where(direction: 'credit') }
  scope :for_funcionario, ->(cod_funcionario) { where(cod_funcionario: cod_funcionario) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }

  # Status helpers
  def pending?
    status == 'pending'
  end

  def applied?
    status == 'applied'
  end

  def cancelled?
    status == 'cancelled'
  end

  def debit?
    direction == 'debit'
  end

  def credit?
    direction == 'credit'
  end

  # Valor efetivo (negativo para débitos, positivo para créditos)
  def effective_amount
    debit? ? -amount : amount
  end

  # Consultas a entidades existentes (somente leitura)
  def funcionario
    Funcionario.find_by(cod_funcionario: cod_funcionario)
  end

  def funcionario_nome
    func = funcionario
    func&.pessoa_nome || func&.usuario
  end

  def venda
    return nil unless cod_venda
    Venda.find_by(cod_venda: cod_venda)
  end
end
