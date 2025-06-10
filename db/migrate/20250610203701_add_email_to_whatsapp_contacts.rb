class AddEmailToWhatsappContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :whatsapp_contacts, :email, :string
  end
end
