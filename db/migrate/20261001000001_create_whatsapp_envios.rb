class CreateWhatsappEnvios < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_envios do |t|
      t.integer  :cod_empresa,     null: false
      t.integer  :cod_pessoa,      null: false
      t.integer  :cod_funcionario, null: true  # colaborador que disparou o envio
      t.integer  :whatsapp_message_id, null: true # mensagem usada (se houver)
      t.string   :canal, default: "aniversario", null: false
      t.string   :telefone
      t.datetime :enviado_em, default: -> { 'CURRENT_TIMESTAMP' }, null: false

      t.timestamps
    end

    add_index :whatsapp_envios, [:cod_empresa, :cod_pessoa, :canal],
              name: "idx_whatsapp_envios_empresa_pessoa_canal"
    add_index :whatsapp_envios, :enviado_em

    add_foreign_key :whatsapp_envios, :empresa, column: :cod_empresa, primary_key: :cod_empresa
    add_foreign_key :whatsapp_envios, :pessoa, column: :cod_pessoa, primary_key: :cod_pessoa
  end
end
