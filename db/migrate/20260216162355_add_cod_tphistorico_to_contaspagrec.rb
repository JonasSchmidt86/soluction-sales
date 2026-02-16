class AddCodTphistoricoToContaspagrec < ActiveRecord::Migration[7.1]
  def change
    add_column :contaspagrec, :cod_tphitorico, :bigint

    add_index :contaspagrec, :cod_tphitorico

    add_foreign_key :contaspagrec,
                    :tiposhistoricoscaixa,
                    column: :cod_tphitorico,
                    primary_key: :cod_tphitorico
  end
end