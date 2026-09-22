class CreateWhatsappMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_messages do |t|
      t.integer :empresa_id, null: false
      t.string :titulo, null: false
      t.text :mensagem, null: false
      t.string :categoria, default: "geral", null: false
      t.boolean :ativo, default: true, null: false
      t.integer :ordem, default: 0, null: false

      t.timestamps
    end

    add_index :whatsapp_messages, [:empresa_id, :ativo, :ordem], name: "idx_whatsapp_messages_empresa_ativo_ordem"
    add_index :whatsapp_messages, [:empresa_id, :categoria], name: "idx_whatsapp_messages_empresa_categoria"
  end
end
