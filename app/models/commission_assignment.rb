class CommissionAssignment < ApplicationRecord
  belongs_to :commission_rule

  # Validações
  validates :cod_funcionario, presence: true
  validates :cod_empresa, presence: true
  validates :start_date, presence: true
  validates :cod_funcionario, uniqueness: {
    scope: [:cod_empresa, :start_date],
    message: 'já possui uma atribuição com esta data de início'
  }
  validate :end_date_after_start_date, if: -> { end_date.present? }
  validate :no_overlapping_assignment, on: :create

  # Scopes
  scope :for_funcionario, ->(cod_funcionario) { where(cod_funcionario: cod_funcionario) }
  scope :for_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }
  scope :active, -> { where(end_date: nil) }
  scope :vigente_em, ->(date) {
    where("start_date <= ?", date)
      .where("end_date IS NULL OR end_date >= ?", date)
  }

  # Encontra a regra vigente para um funcionário em uma data específica
  def self.find_rule_for(cod_funcionario, cod_empresa, date)
    for_funcionario(cod_funcionario)
      .for_empresa(cod_empresa)
      .vigente_em(date)
      .order(start_date: :desc)
      .first
  end

  # Verifica se há mais de uma regra vigente em um intervalo
  def self.rules_in_period(cod_funcionario, cod_empresa, start_date, end_date)
    for_funcionario(cod_funcionario)
      .for_empresa(cod_empresa)
      .where("start_date <= ? AND (end_date IS NULL OR end_date >= ?)", end_date, start_date)
      .order(:start_date)
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

  private

  def end_date_after_start_date
    if end_date < start_date
      errors.add(:end_date, 'deve ser posterior à data de início')
    end
  end

  def no_overlapping_assignment
    overlapping = CommissionAssignment
      .where(cod_funcionario: cod_funcionario, cod_empresa: cod_empresa)
      .where("start_date <= ? AND (end_date IS NULL OR end_date >= ?)", start_date, start_date)

    overlapping = overlapping.where.not(id: id) if persisted?

    if overlapping.exists?
      errors.add(:base, 'Já existe uma atribuição vigente nesta data para este funcionário')
    end
  end
end
