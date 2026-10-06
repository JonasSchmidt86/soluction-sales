class AddNrPedidoToCompra < ActiveRecord::Migration[7.1]
  # Número do pedido de compra (referência ao pedido que originou a compra).
  # String para aceitar qualquer formato (zeros à esquerda, letras).
  def change
    unless column_exists?(:compra, :nr_pedido)
      add_column :compra, :nr_pedido, :string, limit: 30, comment: "numero do pedido de compra"
    end
  end
end
