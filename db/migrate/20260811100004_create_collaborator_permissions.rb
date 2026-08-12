class CreateCollaboratorPermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :collaborator_permissions do |t|
      t.bigint :cod_funcionario, null: false
      t.bigint :cod_empresa, null: false
      t.string :resource, null: false
      t.boolean :can_view, default: false, null: false
      t.boolean :can_create, default: false, null: false
      t.boolean :can_edit, default: false, null: false
      t.boolean :can_delete, default: false, null: false

      t.timestamps
    end

    add_index :collaborator_permissions, [:cod_funcionario, :cod_empresa, :resource],
              unique: true, name: 'idx_collab_permissions_func_emp_resource'
    add_index :collaborator_permissions, :cod_empresa
  end
end
