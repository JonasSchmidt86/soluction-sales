class CreateAtendimentos < ActiveRecord::Migration[7.1]
  def change
    create_table :atendimentos do |t|
      t.integer :cod_empresa, null: false
      t.datetime :data_atendimento, default: -> { 'CURRENT_TIMESTAMP' }, null: false
      t.string :nome
      t.string :telefone
      t.references :origem, null: true, foreign_key: true
      t.boolean :vendeu, default: false, null: false
      t.integer :cod_cliente
      t.text :observacao
      t.timestamps
    end

    add_foreign_key :atendimentos, :empresa, column: :cod_empresa, primary_key: :cod_empresa
    add_foreign_key :atendimentos, :pessoa, column: :cod_cliente, primary_key: :cod_pessoa
  end
end
