class AddCodFuncionarioToContaspagrec < ActiveRecord::Migration[7.1]
  def change
    add_column :contaspagrec, :cod_funcionario, :bigint

    add_index :contaspagrec, :cod_funcionario

    add_foreign_key :contaspagrec,
                    :funcionario,
                    column: :cod_funcionario,
                    primary_key: :cod_funcionario
  end
end