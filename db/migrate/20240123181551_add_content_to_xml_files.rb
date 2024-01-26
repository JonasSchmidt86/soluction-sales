class AddContentToXmlFiles < ActiveRecord::Migration[6.1]
  def change
    add_column :xml_files, :name, :text
  end
end
