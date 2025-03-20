class ProdutoImagem < ApplicationRecord
  self.table_name = "produto_imagens"
  self.primary_key = "id"

  belongs_to :produto, class_name: 'Produto', foreign_key: 'cod_produto', primary_key: 'cod_produto'
  belongs_to :cor, class_name: 'Core', foreign_key: 'cod_cor', primary_key: 'cod_cor', optional: false

  has_one_attached :imagem, service: :produtos_storage

  validates :produto, presence: true
  validates :cor, presence: true

  scope :ordenadas, -> { order(ordem: :asc) }
  scope :principais, -> { where(principal: true) }

  before_save :set_ordem

  private

  def set_ordem
    if ordem.nil? || ordem.zero?
      max_ordem = ProdutoImagem.where(cod_produto: cod_produto, cod_cor: cod_cor).maximum(:ordem) || 0
      self.ordem = max_ordem + 1
    end
  end
end
