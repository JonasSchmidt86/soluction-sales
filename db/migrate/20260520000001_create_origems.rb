class CreateOrigems < ActiveRecord::Migration[7.1]
  def change
    create_table :origems do |t|
      t.string :descricao, null: false
      t.boolean :ativo, default: true, null: false
      t.timestamps
    end
  end
end
