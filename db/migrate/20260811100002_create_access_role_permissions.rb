class CreateAccessRolePermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :access_role_permissions do |t|
      t.references :access_role, null: false, foreign_key: true
      t.string :resource, null: false
      t.boolean :can_view, default: false, null: false
      t.boolean :can_create, default: false, null: false
      t.boolean :can_edit, default: false, null: false
      t.boolean :can_delete, default: false, null: false

      t.timestamps
    end

    add_index :access_role_permissions, [:access_role_id, :resource], unique: true,
              name: 'idx_access_role_permissions_role_resource'
  end
end
