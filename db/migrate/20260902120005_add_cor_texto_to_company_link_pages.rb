class AddCorTextoToCompanyLinkPages < ActiveRecord::Migration[7.1]
  def change
    add_column :company_link_pages, :cor_texto, :string, default: "#ffffff", null: false
  end
end
