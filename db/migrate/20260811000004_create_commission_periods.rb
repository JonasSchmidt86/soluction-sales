class CreateCommissionPeriods < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_periods do |t|
      t.bigint :cod_funcionario, null: false
      t.bigint :cod_empresa, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :status, null: false, default: 'open'
      t.decimal :total_sales, precision: 18, scale: 2
      t.decimal :commission_amount, precision: 18, scale: 2
      t.decimal :adjustments_amount, precision: 18, scale: 2, default: 0
      t.decimal :net_commission, precision: 18, scale: 2
      t.references :commission_rule, foreign_key: true
      t.jsonb :rule_snapshot
      t.jsonb :tiers_breakdown
      t.datetime :finalized_at
      t.bigint :finalized_by
      t.datetime :paid_at
      t.bigint :paid_by
      t.datetime :reopened_at
      t.bigint :reopened_by
      t.text :reopen_reason

      t.timestamps
    end

    add_index :commission_periods, [:cod_funcionario, :cod_empresa, :start_date],
              name: 'idx_commission_periods_func_emp_start'
    add_index :commission_periods, :cod_empresa
    add_index :commission_periods, :status
  end
end
