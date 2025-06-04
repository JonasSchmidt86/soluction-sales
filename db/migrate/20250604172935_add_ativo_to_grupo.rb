class AddAtivoToGrupo < ActiveRecord::Migration[7.1]
  def change
    add_column :grupo, :ativo, :boolean, default: true
  end
end