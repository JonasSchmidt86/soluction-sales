
class AddNaturezaToContaspagrec < ActiveRecord::Migration[7.1]
  def change
    add_column :contaspagrec, :natureza, :integer
    add_index :contaspagrec, :natureza
  end
end