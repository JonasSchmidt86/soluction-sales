class CreateCollaboratorAccessRoles < ActiveRecord::Migration[7.0]
  def change
    create_table :collaborator_access_roles do |t|
      t.references :access_role, null: false, foreign_key: true
      t.bigint :cod_funcionario, null: false
      t.bigint :cod_empresa, null: false

      t.timestamps
    end

    add_index :collaborator_access_roles, [:cod_funcionario, :cod_empresa],
              unique: true, name: 'idx_collab_access_roles_func_emp'
  end
end
