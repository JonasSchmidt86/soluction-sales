class AddCodCorToItensPedidoCompra < ActiveRecord::Migration[7.1]
  def change
    add_column :itens_pedido_compras, :cod_cor, :integer
  end
end
