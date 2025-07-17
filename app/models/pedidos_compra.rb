class PedidosCompra < ApplicationRecord
  belongs_to :pessoa, foreign_key: :cod_pessoa, primary_key: :cod_pessoa
  has_many :itens_pedido_compras, dependent: :destroy
  
  accepts_nested_attributes_for :itens_pedido_compras, allow_destroy: true, reject_if: ->(attrs) { attrs['cod_produto'].blank? }
  
  validates :cod_pessoa, :data_emissao, :itens_pedido_compras,  presence: true

  paginates_per 30

  def calcular_total
    itens_pedido_compras.sum(:valor_total)
  end
end