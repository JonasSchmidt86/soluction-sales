class AddCoresFundoToCompanyLinkPages < ActiveRecord::Migration[7.1]
  def change
    add_column :company_link_pages, :cor_fundo_inicio, :string, default: "#1f2a33", null: false
    add_column :company_link_pages, :cor_fundo_fim, :string, default: "#343a40", null: false
  end
end
