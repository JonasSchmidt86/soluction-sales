class AddPublicTokenToDocumentoFiscal < ActiveRecord::Migration[7.1]
  def change
    # Token curto e aleatorio para o link publico do DANFE/XML (enviado ao
    # cliente). Substitui o signed_id (que gerava URLs enormes). A validade de
    # 30 dias passa a ser verificada pela aplicacao (public_token_expira_em).
    add_column :documento_fiscal, :public_token, :string, limit: 24,
               comment: "token do link publico do DANFE/XML enviado ao cliente"
    add_column :documento_fiscal, :public_token_expira_em, :datetime,
               comment: "validade do link publico (30 dias a partir da geracao)"
    add_index :documento_fiscal, :public_token, unique: true
  end
end
