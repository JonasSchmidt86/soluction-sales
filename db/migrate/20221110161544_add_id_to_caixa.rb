class AddIdToCaixa < ActiveRecord::Migration[5.2]
  
  def change
    add_column :caixa, :id, :serial
  end

end
