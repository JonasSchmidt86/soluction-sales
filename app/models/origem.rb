class Origem < ApplicationRecord
  has_many :atendimentos

  validates :descricao, presence: true
end
