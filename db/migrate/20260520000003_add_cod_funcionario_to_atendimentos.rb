class AddCodFuncionarioToAtendimentos < ActiveRecord::Migration[7.1]
  def change
    add_column :atendimentos, :cod_funcionario, :integer
    add_foreign_key :atendimentos, :funcionario, column: :cod_funcionario, primary_key: :cod_funcionario
  end
end
