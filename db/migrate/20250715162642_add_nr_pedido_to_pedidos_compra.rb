class AddNrPedidoToPedidosCompra < ActiveRecord::Migration[7.1]
  def change
    add_column :pedidos_compras, :nr_pedido, :string, limit: 20
  end
end
