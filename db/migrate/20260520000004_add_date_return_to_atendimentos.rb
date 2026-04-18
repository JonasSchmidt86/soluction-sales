class AddDateReturnToAtendimentos < ActiveRecord::Migration[7.1]
  def change
    add_column :atendimentos, :date_return, :date
  end
end
