class FixEstoqueLogsOperacaoLength < ActiveRecord::Migration[6.1]
  def change
    change_column :estoque_logs, :operacao, :string, limit: 15
  end
end
