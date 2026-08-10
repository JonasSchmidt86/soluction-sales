class CreateMelhoriaHistoricos < ActiveRecord::Migration[7.1]
  def change
    create_table :melhoria_historicos do |t|
      t.references :melhoria, null: false, foreign_key: { to_table: :melhorias }
      t.bigint     :cod_funcionario, null: false
      t.string     :campo, null: false
      t.string     :valor_anterior
      t.string     :valor_novo

      t.timestamps
    end

    add_index :melhoria_historicos, :cod_funcionario
  end
end
