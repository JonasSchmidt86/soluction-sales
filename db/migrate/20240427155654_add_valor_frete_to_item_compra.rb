class AddValorFreteToItemCompra < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:itemcompra, :valor_frete)
      add_column :itemcompra, :valor_frete, :decimal, precision: 10, default: 0, scale: 2
    end
  end
end