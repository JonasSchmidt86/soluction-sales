class AddCodFuncionarioToAcertosestoque < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:acertosestoque, :cod_funcionario)
      add_column :acertosestoque, :cod_funcionario, :bigint, default: 1
    end
  end
end
