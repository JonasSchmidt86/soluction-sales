class AddOrigemSistemaToEstoqueLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :estoque_logs, :origem_sistema, :string, limit: 15
  end
end
