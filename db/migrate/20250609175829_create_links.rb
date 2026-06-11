class CreateLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :links do |t|
      t.string :label
      t.string :url
      t.integer :position
      t.boolean :active

      t.timestamps
    end
  end
end
