class CreateProdutoImagens < ActiveRecord::Migration[7.1]
  def change
    create_table :produto_imagens, id: false do |t|  # A opção `id: false` indica que não usaremos o `id` padrão
      t.primary_key :id  # Especifica que a chave primária será `id`
      t.string :name, limit: 100
      t.integer :cod_produto, null: false
      t.integer :cod_grupo, default: nil
      t.integer :ordem, default: 0
      t.boolean :principal, default: false
      t.integer :cod_cor, default: 1
      t.timestamps
    end

    add_index :produto_imagens, :cod_produto
    add_index :produto_imagens, [:cod_produto, :cod_grupo]
    add_index :produto_imagens, [:cod_produto, :cod_cor]
    add_index :produto_imagens, [:cod_produto, :principal]

    add_foreign_key :produto_imagens, :grupo, column: :cod_grupo, primary_key: :cod_grupo
    add_foreign_key :produto_imagens, :cores, column: :cod_cor, primary_key: :cod_cor
    add_foreign_key :produto_imagens, :produto, column: :cod_produto, primary_key: :cod_produto
  end
end
