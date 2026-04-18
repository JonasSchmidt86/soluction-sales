class RenameRemainingFieldsAtendimentos < ActiveRecord::Migration[7.1]
  def change
    rename_column :atendimentos, :nome, :name
    rename_column :atendimentos, :telefone, :phone
    rename_column :atendimentos, :observacao, :notes

    rename_column :atendimentos, :cod_funcionario, :employee_id
    rename_column :atendimentos, :cod_cliente, :customer_id
    rename_column :atendimentos, :cod_empresa, :company_id

    add_index :atendimentos, :company_id
    add_index :atendimentos, :customer_id
    add_index :atendimentos, :employee_id
  end
end