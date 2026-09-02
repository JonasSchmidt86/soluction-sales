class AddFormatoImagemToCompanyLinkPages < ActiveRecord::Migration[7.1]
  def change
    add_column :company_link_pages, :formato_imagem, :string, default: "redonda", null: false
  end
end
