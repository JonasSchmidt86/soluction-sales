class AddIdToEmpresaproduto < ActiveRecord::Migration[5.2]
  def change
    add_column :empresaproduto, :id, :serial
  end
end
