class CreatePedidosCompra < ActiveRecord::Migration[7.1]
  def change
    create_table :pedidos_compras do |t|
      t.integer :cod_pessoa, null: false
      t.date :data_emissao, null: false
      t.date :data_entrega
      t.text :observacoes
      t.decimal :total, precision: 10, scale: 2

      t.timestamps
    end
    
    add_foreign_key :pedidos_compras, :pessoa, column: :cod_pessoa, primary_key: :cod_pessoa
    add_index :pedidos_compras, :cod_pessoa
  end
end
