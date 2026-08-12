class CommissionTier < ApplicationRecord
  belongs_to :commission_rule

  # Validações
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :commission_rule_id }
  validates :min_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_value, numericality: { greater_than: :min_value }, allow_nil: true
  validates :percentage, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :ordered, -> { order(:position) }

  # Retorna o tamanho da faixa (nil se ilimitada)
  def range_size
    return nil if max_value.nil?
    max_value - min_value
  end

  # Verifica se a faixa é ilimitada (última faixa)
  def unlimited?
    max_value.nil?
  end
end
