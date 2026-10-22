class AddCredenciaisBrasilnfeToFiscalConfig < ActiveRecord::Migration[7.1]
  # Credenciais do provedor (Brasil NFe) POR EMPRESA, para substituir o token
  # unico/global que ficava em credentials.yml.enc (inviavel com multiplas
  # empresas). Valores sensiveis (tokens e CSC) sao gravados CRIPTOGRAFADOS via
  # Active Record Encryption (encrypts no model), por isso as colunas sao :text
  # (o ciphertext e maior que o texto puro).
  #
  # Token da EMPRESA (transmissao de documentos): UNICO — o ambiente
  # (producao/homologacao) e decidido na requisicao (TipoAmbiente), nao e um
  # token por ambiente. UserToken e da CONTA (gestao /services/empresa), tambem
  # unico. Ja o CSC da NFC-e e separado por ambiente (padrao do provedor).
  def change
    change_table :fiscal_config, bulk: true do |t|
      # Token da empresa (emissao/transmissao) — unico.
      t.text :brasilnfe_token,      comment: "Token Brasil NFe da empresa (transmissao) — criptografado"
      # Token da conta (gestao /services/empresa) — unico.
      t.text :brasilnfe_user_token, comment: "UserToken Brasil NFe da conta — criptografado"

      # CSC da NFC-e por ambiente (id nao e sensivel; token do CSC e -> criptografado).
      t.string :csc_id_producao,    limit: 20, comment: "Ident. CSC producao (idToken)"
      t.text   :csc_token_producao, comment: "CSC producao — criptografado"
      t.string :csc_id_homologacao, limit: 20, comment: "Ident. CSC homologacao (idToken)"
      t.text   :csc_token_homologacao, comment: "CSC homologacao — criptografado"
    end
  end
end
