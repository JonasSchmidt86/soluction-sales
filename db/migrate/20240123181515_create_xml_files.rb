class CreateXmlFiles < ActiveRecord::Migration[6.1]
  def change
    create_table :xml_files do |t|

      t.timestamps
    end
  end
end
