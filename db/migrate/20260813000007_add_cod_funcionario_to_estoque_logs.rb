class AddCodFuncionarioToEstoqueLogs < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:estoque_logs, :cod_funcionario)
      add_column :estoque_logs, :cod_funcionario, :bigint
    end
  end
end
