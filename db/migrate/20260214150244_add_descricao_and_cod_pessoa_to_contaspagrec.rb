class AddDescricaoAndCodPessoaToContaspagrec < ActiveRecord::Migration[7.1]
  def change
    add_column :contaspagrec, :descricao, :string
    add_column :contaspagrec, :cod_pessoa, :bigint

    add_index :contaspagrec, :cod_pessoa
  end
end