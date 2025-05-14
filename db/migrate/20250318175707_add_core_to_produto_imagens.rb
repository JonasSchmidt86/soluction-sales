class AddCoreToProdutoImagens < ActiveRecord::Migration[7.1]
  unless column_exists?(:produto_imagens, :cod_cor)
    def change
      add_column :produto_imagens, :cod_cor, :integer
    end
  end
end
