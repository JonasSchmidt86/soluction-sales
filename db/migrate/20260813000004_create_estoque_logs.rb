class CreateEstoqueLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :estoque_logs do |t|
      t.bigint :cod_empresa, null: false
      t.bigint :cod_produto, null: false
      t.bigint :cod_cor, null: false
      t.string :operacao, limit: 10, null: false
      t.string :origem, limit: 15, null: false
      t.decimal :quantidade_antes, precision: 15, scale: 2
      t.decimal :quantidade_movida, precision: 15, scale: 2
      t.decimal :quantidade_depois, precision: 15, scale: 2
      t.bigint :cod_referencia
      t.bigint :cod_item
      t.decimal :custofinal, precision: 15, scale: 2
      t.string :usuario, limit: 100
      t.string :observacao, limit: 255
      t.timestamp :created_at, default: -> { 'CURRENT_TIMESTAMP' }, null: false
    end

    add_index :estoque_logs, [:cod_empresa, :cod_produto, :cod_cor], name: 'idx_estoque_logs_produto'
    add_index :estoque_logs, :created_at, name: 'idx_estoque_logs_data'
    add_index :estoque_logs, [:origem, :cod_referencia], name: 'idx_estoque_logs_origem_ref'
  end
end
