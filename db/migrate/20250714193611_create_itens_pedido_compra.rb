class CreateItensPedidoCompra < ActiveRecord::Migration[7.1]
  def change
    create_table :itens_pedido_compras do |t|
      t.references :pedidos_compra, null: false, foreign_key: true
      t.integer :cod_produto, null: false
      t.decimal :quantidade, precision: 10, scale: 3, null: false
      t.decimal :valor_unitario, precision: 10, scale: 2, null: false
      t.decimal :percentual_ipi, precision: 5, scale: 2, default: 0
      t.decimal :valor_ipi, precision: 10, scale: 2, default: 0
      t.decimal :percentual_icms, precision: 5, scale: 2, default: 0
      t.decimal :valor_icms, precision: 10, scale: 2, default: 0
      t.decimal :valor_total, precision: 10, scale: 2, null: false

      t.timestamps
    end
    
    add_foreign_key :itens_pedido_compras, :produto, column: :cod_produto, primary_key: :cod_produto
    add_index :itens_pedido_compras, :cod_produto
  end
end
