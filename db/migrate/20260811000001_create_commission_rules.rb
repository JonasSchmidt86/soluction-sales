class CreateCommissionRules < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_rules do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :cod_empresa, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :commission_rules, :cod_empresa
    add_index :commission_rules, [:cod_empresa, :name], unique: true
  end
end
