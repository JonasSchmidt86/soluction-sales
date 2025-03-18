class CreateProdutoImagens < ActiveRecord::Migration[7.1]
  def change
    create_table :produto_imagens do |t|
      t.integer :cod_produto, null: false
      t.string :imagem, null: false
      t.integer :grupo, default: 0
      t.integer :ordem, default: 0
      t.boolean :principal, default: false

      t.timestamps
    end

    add_index :produto_imagens, :cod_produto
    add_index :produto_imagens, [:cod_produto, :grupo]
    add_index :produto_imagens, [:cod_produto, :principal]
  end
end 