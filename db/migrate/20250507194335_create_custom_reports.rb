class CreateCustomReports < ActiveRecord::Migration[7.1]
  def change
    create_table :custom_reports do |t|
      t.string :title
      t.text :description
      t.text :sql_code
      t.json :params_schema

      t.timestamps
    end
  end
end
