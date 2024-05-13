class AddValorFreteToItemCompra < ActiveRecord::Migration[6.1]
  def change
    add_column :itemcompra, :valor_frete, :decimal, precision: 10, scale: 2
  end
end
