class AddRowSpanToDashboardWidgets < ActiveRecord::Migration[7.0]
  def change
    # Altura do widget em "unidades" de grade (cada unidade ~= 90px na view).
    add_column :dashboard_widgets, :row_span, :integer, null: false, default: 3
  end
end
