class AddValorAndDescricaoToProduto < ActiveRecord::Migration[7.1]
  def change
    add_column :produto, :descricao, :text
    add_column :empresaproduto, :valor_site, :decimal, precision: 18, scale: 2, default: 0.0
    add_column :empresaproduto, :publicado, :boolean, default: false
  end
end
