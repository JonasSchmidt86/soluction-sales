class AddColSpanToDashboardWidgets < ActiveRecord::Migration[7.0]
  def up
    add_column :dashboard_widgets, :col_span, :integer, null: false, default: 6

    # Converte o tamanho textual atual (sm/md/lg) para largura em colunas (grid de 12)
    execute <<~SQL
      UPDATE dashboard_widgets SET col_span = CASE size
        WHEN 'sm' THEN 4
        WHEN 'md' THEN 6
        WHEN 'lg' THEN 12
        ELSE 6
      END
    SQL
  end

  def down
    remove_column :dashboard_widgets, :col_span
  end
end
