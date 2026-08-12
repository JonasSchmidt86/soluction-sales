class CommissionPeriodSale < ApplicationRecord
  belongs_to :commission_period

  # Validações
  validates :cod_venda, presence: true
  validates :cod_venda, uniqueness: { scope: :commission_period_id,
    message: 'já está incluída nesta apuração' }
  validates :sale_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sale_date, presence: true
  validates :commission_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(:sale_date, :cod_venda) }

  # Consulta a venda existente (somente leitura)
  def venda
    Venda.find_by(cod_venda: cod_venda)
  end

  def venda_cancelada?
    Venda.where(cod_venda: cod_venda, cancelada: true).exists?
  end
end
