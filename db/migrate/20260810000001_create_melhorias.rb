class CreateMelhorias < ActiveRecord::Migration[7.1]
  def change
    create_table :melhorias do |t|
      t.string   :titulo, null: false
      t.text     :descricao
      t.integer  :tipo, null: false, default: 0
      t.integer  :status, null: false, default: 0
      t.integer  :prioridade, null: false, default: 1
      t.bigint   :cod_funcionario, null: false
      t.bigint   :cod_empresa, null: false
      t.bigint   :responsavel_id

      t.timestamps
    end

    add_index :melhorias, :cod_funcionario
    add_index :melhorias, :cod_empresa
    add_index :melhorias, :responsavel_id
    add_index :melhorias, :status
    add_index :melhorias, :tipo
    add_index :melhorias, :prioridade
  end
end
