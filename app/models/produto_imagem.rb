class ProdutoImagem < ApplicationRecord

  self.table_name = "produto_imagens"
  self.pluralize_table_names = false
  self.primary_key = "id"
  
  belongs_to :produto,:class_name => 'Produto', foreign_key: 'cod_produto', primary_key: 'cod_produto'
  belongs_to :core, :class_name => 'Core', foreign_key: 'cod_cor', primary_key: 'cod_cor', optional: true
  
  mount_uploader :imagem, ProdutoImagemUploader
  
  validates :imagem, presence: true
  validates :produto, presence: true
  validates :grupo, presence: true
  
  enum grupo: {
    geral: 0,
    detalhes: 1,
    variacoes: 2
  }
  
  scope :ordenadas, -> { order(ordem: :asc) }
  scope :por_grupo, ->(grupo) { where(grupo: grupo) }
  scope :principais, -> { where(principal: true) }
  
  def self.grupos_disponiveis
    grupos.keys
  end
  
  before_save :set_ordem
  
  private
  
  def set_ordem
    if ordem.zero?
      max_ordem = ProdutoImagem.where(cod_produto: cod_produto, grupo: grupo).maximum(:ordem) || 0
      self.ordem = max_ordem + 1
    end
  end
end 