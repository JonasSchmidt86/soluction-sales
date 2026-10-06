class DocumentoFiscalEvento < ApplicationRecord
  self.table_name = "documento_fiscal_evento"
  self.primary_key = "cod_documento_fiscal_evento"

  TIPOS = %w[cancelamento carta_correcao inutilizacao].freeze

  belongs_to :documento_fiscal, class_name: "DocumentoFiscal",
             foreign_key: "cod_documento_fiscal", primary_key: "cod_documento_fiscal",
             inverse_of: :eventos

  belongs_to :funcionario, class_name: "Funcionario",
             foreign_key: "cod_funcionario", primary_key: "cod_funcionario",
             optional: true

  validates :tipo, presence: true, inclusion: { in: TIPOS }

  scope :cancelamentos, -> { where(tipo: "cancelamento") }

  def registrado_por
    funcionario&.usuario
  end
end
