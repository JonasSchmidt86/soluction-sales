class CreateCommissionAssignments < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_assignments do |t|
      t.references :commission_rule, null: false, foreign_key: true
      t.bigint :cod_funcionario, null: false
      t.bigint :cod_empresa, null: false
      t.date :start_date, null: false
      t.date :end_date
      t.bigint :created_by

      t.timestamps
    end

    add_index :commission_assignments, [:cod_funcionario, :cod_empresa, :start_date],
              unique: true, name: 'idx_commission_assignments_func_emp_start'
    add_index :commission_assignments, :cod_empresa
  end
end
