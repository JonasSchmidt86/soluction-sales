class CreateSocialLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :social_links do |t|
      t.references :company_link_page, null: false, foreign_key: true
      t.string  :tipo, null: false, default: "outro"
      t.string  :titulo
      t.string  :url, null: false
      t.integer :ordem, default: 0, null: false
      t.boolean :ativo, default: true, null: false

      t.timestamps
    end

    add_index :social_links, [:company_link_page_id, :ordem]
  end
end
