# Nota fiscal de ENTRADA recebida de fornecedor (emitida CONTRA o CNPJ da empresa).
# Alimentada automaticamente pela SEFAZ (via Brasil NFe ObterNotasFiscais entradas)
# ou por upload manual. Guarda o resumo + status SEFAZ, independente de ter virado
# Compra. Quando importada, aponta para a Compra (cod_compra) e o XmlFile.
class NotaRecebida < ApplicationRecord
  self.table_name = "nota_recebida"
  self.primary_key = "cod_nota_recebida"

  STATUS = %w[autorizada cancelada denegada desconhecida].freeze

  paginates_per 30

  belongs_to :empresa, class_name: "Empresa", foreign_key: "cod_empresa"
  belongs_to :pessoa,  class_name: "Pessoa",  foreign_key: "cod_pessoa", optional: true
  belongs_to :compra,  class_name: "Compra",  foreign_key: "cod_compra", optional: true
  belongs_to :xml_file, class_name: "XmlFile", foreign_key: "xml_file_id", optional: true

  validates :cod_empresa, :chave_acesso, presence: true
  validates :chave_acesso, uniqueness: { scope: :cod_empresa }

  scope :da_empresa,   ->(cod) { where(cod_empresa: cod) }
  scope :autorizadas,  -> { where(status_sefaz: "autorizada") }
  scope :canceladas,   -> { where(status_sefaz: "cancelada") }
  scope :integradas,   -> { where.not(cod_compra: nil) }
  scope :nao_integradas, -> { where(cod_compra: nil) }
  scope :recentes,     -> { order(data_emissao: :desc, cod_nota_recebida: :desc) }

  def integrada?
    cod_compra.present?
  end

  def cancelada?
    status_sefaz == "cancelada"
  end

  # Caso de ALERTA: a nota ja virou compra no sistema mas foi CANCELADA na SEFAZ.
  # O usuario precisa cancelar a compra correspondente.
  def integrada_mas_cancelada?
    integrada? && cancelada?
  end
end
