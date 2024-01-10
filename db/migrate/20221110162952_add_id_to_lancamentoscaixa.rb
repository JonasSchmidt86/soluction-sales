class AddIdToLancamentoscaixa < ActiveRecord::Migration[5.2]
  def change
    add_column :lancamentoscaixa, :caixa_id, :bigint;
  end
end
