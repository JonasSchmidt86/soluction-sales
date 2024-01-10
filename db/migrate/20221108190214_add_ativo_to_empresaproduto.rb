class AddAtivoToEmpresaproduto < ActiveRecord::Migration[5.2]
  def change
    add_column :empresaproduto, :ativo, :boolean, default: true
  end
end
