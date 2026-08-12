class CommissionPeriod < ApplicationRecord
  # Relacionamentos internos
  has_many :commission_period_sales, dependent: :destroy
  has_many :commission_adjustments, dependent: :restrict_with_error
  has_many :applied_adjustments, class_name: 'CommissionAdjustment',
           foreign_key: :applied_in_period_id
  has_many :commission_payments, dependent: :restrict_with_error
  belongs_to :commission_rule, optional: true

  # Validações
  validates :cod_funcionario, presence: true
  validates :cod_empresa, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[open finalized paid] }
  validate :end_date_after_start_date

  # Scopes
  scope :for_funcionario, ->(cod_funcionario) { where(cod_funcionario: cod_funcionario) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }
  scope :open_periods, -> { where(status: 'open') }
  scope :finalized, -> { where(status: 'finalized') }
  scope :paid, -> { where(status: 'paid') }
  scope :closed, -> { where(status: %w[finalized paid]) }

  # Status helpers
  def open?
    status == 'open'
  end

  def finalized?
    status == 'finalized'
  end

  def paid?
    status == 'paid'
  end

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

  def empresa_nome
    Empresa.where(cod_empresa: cod_empresa).pluck(:nome).first
  end

  # Busca vendas válidas do período (somente leitura na tabela venda)
  def fetch_sales
    Venda.where(cod_funcionario: cod_funcionario, cod_empresa: cod_empresa)
         .where(cancelada: [false, nil])
         .where.not(tipo: 'T')
         .where("datavenda >= ? AND datavenda <= ?", start_date.beginning_of_day, end_date.end_of_day)
         .order(:datavenda, :cod_venda)
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    if end_date < start_date
      errors.add(:end_date, 'deve ser posterior à data de início')
    end
  end
end
