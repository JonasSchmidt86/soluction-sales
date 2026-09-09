class CreateDashboardWidgets < ActiveRecord::Migration[7.0]
  def change
    create_table :dashboard_widgets do |t|
      t.bigint  :cod_funcionario, null: false
      t.bigint  :cod_empresa, null: false
      t.string  :widget_type, null: false
      t.integer :position, default: 0, null: false
      t.string  :size, default: 'md', null: false
      t.boolean :visible, default: true, null: false
      t.jsonb   :config, default: {}, null: false

      t.timestamps
    end

    add_index :dashboard_widgets, [:cod_funcionario, :cod_empresa, :widget_type],
              unique: true, name: 'idx_dashboard_widgets_func_emp_type'
    add_index :dashboard_widgets, [:cod_funcionario, :cod_empresa],
              name: 'idx_dashboard_widgets_func_emp'
  end
end
