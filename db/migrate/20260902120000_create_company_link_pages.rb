class CreateCompanyLinkPages < ActiveRecord::Migration[7.1]
  def change
    create_table :company_link_pages do |t|
      t.integer :empresa_id, null: false
      t.string  :slug, null: false
      t.string  :titulo
      t.string  :descricao
      t.boolean :publicado, default: false, null: false

      t.timestamps
    end

    add_index :company_link_pages, :slug, unique: true
    add_index :company_link_pages, :empresa_id, unique: true
  end
end
