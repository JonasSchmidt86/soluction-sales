class PerfilTributario < ApplicationRecord
  self.table_name = "perfil_tributario"
  self.primary_key = "cod_perfil_tributario"

  has_many :regras, class_name: "RegraFiscal",
           foreign_key: "cod_perfil_tributario", primary_key: "cod_perfil_tributario",
           dependent: :destroy, inverse_of: :perfil
  accepts_nested_attributes_for :regras, allow_destroy: true, reject_if: :all_blank

  has_many :produtos, class_name: "Produto",
           foreign_key: "cod_perfil_tributario", primary_key: "cod_perfil_tributario"

  TIPOS = %w[saida entrada].freeze

  validates :nome, presence: true
  validates :tipo, inclusion: { in: TIPOS }

  scope :ativos, -> { where(ativo: true) }
  scope :de_saida,   -> { where(tipo: "saida") }
  scope :de_entrada, -> { where(tipo: "entrada") }

  def to_s
    nome
  end
end
