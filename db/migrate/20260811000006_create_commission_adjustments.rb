class CreateCommissionAdjustments < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_adjustments do |t|
      t.bigint :cod_funcionario, null: false
      t.bigint :cod_empresa, null: false
      t.bigint :cod_venda
      t.references :commission_period, foreign_key: true
      t.bigint :applied_in_period_id
      t.string :adjustment_type, null: false
      t.string :direction, null: false, default: 'debit'
      t.text :reason
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.string :status, null: false, default: 'pending'
      t.bigint :created_by
      t.datetime :applied_at

      t.timestamps
    end

    add_foreign_key :commission_adjustments, :commission_periods,
                    column: :applied_in_period_id

    add_index :commission_adjustments, [:cod_venda, :commission_period_id, :adjustment_type],
              unique: true, name: 'idx_commission_adj_venda_period_type'
    add_index :commission_adjustments, [:cod_funcionario, :cod_empresa]
    add_index :commission_adjustments, :status
    add_index :commission_adjustments, :applied_in_period_id
  end
end
