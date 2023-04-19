class AddEmpresaToCollaborators < ActiveRecord::Migration[5.2]
  def change
    add_column :collaborators, :cod_funcionario, :bigint
    add_column :collaborators, :cod_empresa, :bigint
  end
end
