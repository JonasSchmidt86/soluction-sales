class CommissionPayment < ApplicationRecord
  belongs_to :commission_period

  # Validações
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
  validates :paid_by, presence: true

  # Consulta a entidade existente (somente leitura)
  def paid_by_funcionario
    Funcionario.find_by(cod_funcionario: paid_by)
  end

  def paid_by_nome
    func = paid_by_funcionario
    func&.pessoa_nome || func&.usuario
  end
end
