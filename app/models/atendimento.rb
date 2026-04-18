class Atendimento < ApplicationRecord
  belongs_to :origem, optional: true
  belongs_to :empresa, foreign_key: :company_id, primary_key: :cod_empresa, optional: true
  belongs_to :pessoa, foreign_key: :customer_id, primary_key: :cod_pessoa, optional: true
  belongs_to :funcionario, foreign_key: :employee_id, primary_key: :cod_funcionario, optional: true

  validates :company_id, presence: true
  validates :attended_at, presence: true

  enum status: {
    open: 0,
    in_progress: 1,
    awaiting_return: 2,
    closed: 3
  }

  def status_color
    return "success" if closed?

    return "danger" if return_at.present? && return_at < Date.today

    return "warning" if return_at.present? && return_at.to_date == Date.today

    "secondary"
  end

end
