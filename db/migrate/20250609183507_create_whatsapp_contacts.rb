class CreateWhatsappContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_contacts do |t|
      t.references :empresa, null: false, foreign_key: false # desliga FK automático porque a tabela é singular
      t.bigint :funcionario_id, null: false
      
      t.string :whatsapp_number, null: false
      t.string :display_name

      t.timestamps
    end

    # agora adiciona as foreign keys explicitamente, pois as tabelas não seguem padrão plural Rails
    add_foreign_key :whatsapp_contacts, :empresa, column: :empresa_id, primary_key: "cod_empresa"
    add_foreign_key :whatsapp_contacts, :funcionario, column: :funcionario_id, primary_key: "cod_funcionario"

    # add_index :whatsapp_contacts, :empresa_id
    # add_index :whatsapp_contacts, :funcionario_id
  end
end
