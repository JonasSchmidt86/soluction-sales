class AddCodEmpresaToPedidosCompras < ActiveRecord::Migration[7.1]
  def change
    add_column :pedidos_compras, :cod_empresa, :integer, null: false

    add_foreign_key :pedidos_compras, :empresa, column: :cod_empresa, primary_key: :cod_empresa
    add_index :pedidos_compras, :cod_empresa
  end
end
