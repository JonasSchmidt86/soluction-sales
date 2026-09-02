class AddPublicarLinkToWhatsappContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :whatsapp_contacts, :publicar_link, :boolean, default: false, null: false
    add_column :whatsapp_contacts, :ordem, :integer, default: 0, null: false
  end
end
