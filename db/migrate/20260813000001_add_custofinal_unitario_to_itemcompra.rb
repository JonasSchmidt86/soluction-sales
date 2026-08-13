class AddCustofinalUnitarioToItemcompra < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:itemcompra, :custofinal_unitario)
      add_column :itemcompra, :custofinal_unitario, :decimal, precision: 15, scale: 2, default: 0
    end
  end
end
