class AddUrlToCadinternalframes < ActiveRecord::Migration[7.1]
  def change
    add_column :cadinternalframes, :url, :string
  end
end
