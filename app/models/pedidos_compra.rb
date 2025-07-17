class PedidosCompra < ApplicationRecord

  belongs_to :pessoa, foreign_key: :cod_pessoa, primary_key: :cod_pessoa
  
  has_many :itens_pedido_compras, after_add: :recalcular_total, after_remove: :recalcular_total, dependent: :destroy

  belongs_to :empresa, foreign_key: :cod_empresa, primary_key: :cod_empresa

  accepts_nested_attributes_for :itens_pedido_compras, allow_destroy: true, reject_if: ->(attrs) { attrs['cod_produto'].blank? }
  
  validates :cod_pessoa, :data_emissao, :itens_pedido_compras,  presence: true

  paginates_per 30

  def recalcular_total(_item = nil)
    self.total = calcular_total
  end

  def calcular_total
    itens_pedido_compras.sum(:valor_total)
  end
end