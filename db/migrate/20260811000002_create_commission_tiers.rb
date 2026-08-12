class CreateCommissionTiers < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_tiers do |t|
      t.references :commission_rule, null: false, foreign_key: true
      t.integer :position, null: false
      t.decimal :min_value, precision: 18, scale: 2, null: false
      t.decimal :max_value, precision: 18, scale: 2
      t.decimal :percentage, precision: 8, scale: 4, null: false

      t.timestamps
    end

    add_index :commission_tiers, [:commission_rule_id, :position], unique: true
  end
end
