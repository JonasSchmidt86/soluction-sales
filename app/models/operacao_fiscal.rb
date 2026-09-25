class OperacaoFiscal < ApplicationRecord
  self.table_name = "operacao_fiscal"
  self.primary_key = "cod_operacao_fiscal"

  TIPOS = %w[saida entrada].freeze

  has_many :regras, class_name: "RegraFiscal",
           foreign_key: "cod_operacao_fiscal", primary_key: "cod_operacao_fiscal",
           dependent: :restrict_with_error, inverse_of: :operacao

  validates :nome, presence: true
  validates :tipo, presence: true, inclusion: { in: TIPOS }

  scope :ativos, -> { where(ativo: true) }
  scope :saidas, -> { where(tipo: "saida") }
  scope :entradas, -> { where(tipo: "entrada") }

  def to_s
    nome
  end
end
