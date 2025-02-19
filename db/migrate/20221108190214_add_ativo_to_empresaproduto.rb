class AddAtivoToEmpresaproduto < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:empresaproduto, :ativo)
      add_column :empresaproduto, :ativo, :boolean, default: true
    end
  end
end
