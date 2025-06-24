class AddTituloToProdutos < ActiveRecord::Migration[7.1]
  def change
    add_column :produto, :titulo, :string, limit: 100
  end
end
