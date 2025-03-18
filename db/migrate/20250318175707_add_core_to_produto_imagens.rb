class AddCoreToProdutoImagens < ActiveRecord::Migration[7.1]
  def change
    add_column :produto_imagens, :cod_cor, :integer
  end
end
