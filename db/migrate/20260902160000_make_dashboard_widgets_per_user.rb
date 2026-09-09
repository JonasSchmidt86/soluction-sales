class MakeDashboardWidgetsPerUser < ActiveRecord::Migration[7.0]
  def up
    # Consolida o layout por usuário: mantém apenas os registros da MENOR
    # cod_empresa de cada colaborador e remove os das demais empresas,
    # evitando duplicidade de widget_type por usuário.
    execute <<~SQL
      DELETE FROM dashboard_widgets dw
      USING (
        SELECT cod_funcionario, MIN(cod_empresa) AS keep_empresa
        FROM dashboard_widgets
        GROUP BY cod_funcionario
      ) base
      WHERE dw.cod_funcionario = base.cod_funcionario
        AND dw.cod_empresa <> base.keep_empresa
    SQL

    # Índice único passa a ser só por (cod_funcionario, widget_type)
    remove_index :dashboard_widgets, name: 'idx_dashboard_widgets_func_emp_type', if_exists: true
    remove_index :dashboard_widgets, name: 'idx_dashboard_widgets_func_emp', if_exists: true

    add_index :dashboard_widgets, [:cod_funcionario, :widget_type],
              unique: true, name: 'idx_dashboard_widgets_func_type'
    add_index :dashboard_widgets, :cod_funcionario,
              name: 'idx_dashboard_widgets_func'
  end

  def down
    remove_index :dashboard_widgets, name: 'idx_dashboard_widgets_func_type', if_exists: true
    remove_index :dashboard_widgets, name: 'idx_dashboard_widgets_func', if_exists: true

    add_index :dashboard_widgets, [:cod_funcionario, :cod_empresa, :widget_type],
              unique: true, name: 'idx_dashboard_widgets_func_emp_type'
    add_index :dashboard_widgets, [:cod_funcionario, :cod_empresa],
              name: 'idx_dashboard_widgets_func_emp'
  end
end
