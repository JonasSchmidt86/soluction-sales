class AddQtdfiscalToEstoqueLogs < ActiveRecord::Migration[7.1]
  # Registra a movimentacao do estoque FISCAL (qtdfiscal) na MESMA linha do log,
  # ao lado das colunas de estoque fisico (quantidade_antes/movida/depois).
  # Assim cada movimentacao mostra o impacto no fisico E no fiscal.
  def change
    unless column_exists?(:estoque_logs, :qtdfiscal_antes)
      add_column :estoque_logs, :qtdfiscal_antes,  :decimal, precision: 15, scale: 2
      add_column :estoque_logs, :qtdfiscal_movida,  :decimal, precision: 15, scale: 2
      add_column :estoque_logs, :qtdfiscal_depois,  :decimal, precision: 15, scale: 2
    end
  end
end
