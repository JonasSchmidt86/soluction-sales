class CreateMelhoriaComentarios < ActiveRecord::Migration[7.1]
  def change
    create_table :melhoria_comentarios do |t|
      t.references :melhoria, null: false, foreign_key: { to_table: :melhorias }
      t.bigint     :cod_funcionario, null: false
      t.text       :comentario, null: false

      t.timestamps
    end

    add_index :melhoria_comentarios, :cod_funcionario
  end
end
