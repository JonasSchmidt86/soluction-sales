class Grupo < ApplicationRecord
    
  self.table_name = "grupo"
  self.primary_key = "cod_grupo"

  # Alias para tornar o nome mais amigável no Rails
  alias_attribute :nome, :nomegrupo

  # Relacionamento com Parametro
  belongs_to :parametro, foreign_key: 'cod_margem', optional: true

  # Relacionamento com Produto
  has_many :produtos, foreign_key: 'grupo', primary_key: 'cod_grupo', class_name: 'Produto', dependent: :restrict_with_error
  has_many :produto_imagens, through: :produtos

  # Validações
  validates :nome, presence: true, uniqueness: { case_sensitive: false, message: "já está cadastrado" }

  # Scopes
  scope :ativos, -> { where(ativo: true) } if column_names.include?('ativo')

  # Métodos auxiliares
  def cod_nome
    "#{nome} - #{cod_grupo}"
  end

  def to_s
    nome
  end

  paginates_per 30
end
