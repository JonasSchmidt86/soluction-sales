# Pacote fiscal gerado (zip de XML/PDF ou Excel) de um periodo. O arquivo fica
# SALVO (Active Storage, mesmo service dos XMLs) para baixar/reenviar ao contador
# sem precisar chamar o provedor de novo. Historico com data, periodo e envio.
class PacoteFiscal < ApplicationRecord
  self.table_name = "pacote_fiscal"
  self.primary_key = "cod_pacote_fiscal"

  has_one_attached :arquivo, service: :xml_storage

  belongs_to :empresa, class_name: "Empresa", foreign_key: "cod_empresa"

  validates :cod_empresa, :periodo_inicio, :periodo_fim, presence: true

  scope :da_empresa, ->(cod) { where(cod_empresa: cod) }
  scope :recentes,   -> { order(gerado_em: :desc, cod_pacote_fiscal: :desc) }

  paginates_per 30

  TIPO_ARQUIVO = { 0 => "PDF", 1 => "XML", 2 => "Excel" }.freeze
  TIPO_NOTA    = { 1 => "Saídas", 2 => "Entradas", 3 => "Saídas e entradas" }.freeze

  def tipo_arquivo_label; TIPO_ARQUIVO[tipo_arquivo.to_i] || "—"; end
  def tipo_nota_label;    TIPO_NOTA[tipo_nota.to_i] || "—"; end

  def enviado?
    enviado_contador_em.present?
  end

  # Conteudo binario do pacote salvo (para baixar/anexar no e-mail).
  def conteudo
    arquivo.download if arquivo.attached?
  end
end
