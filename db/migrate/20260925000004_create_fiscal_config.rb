class CreateFiscalConfig < ActiveRecord::Migration[7.1]
  def change
    # Configuracao fiscal por estabelecimento (empresa).
    # Neutra em relacao ao provedor (Focus x Brasil NFe): guarda apenas o que
    # o EMITENTE precisa. Credenciais/token do provedor NAO ficam aqui em texto
    # no repo — quando definir o provedor, guardar via credentials/env.
    unless table_exists?(:fiscal_config)
      create_table :fiscal_config, primary_key: :cod_fiscal_config do |t|
        t.bigint  :cod_empresa, null: false

        # Ambiente e regime
        t.string  :ambiente, limit: 12, default: "homologacao", null: false,
                  comment: "homologacao / producao"
        t.string  :regime_tributario, limit: 20, default: "simples", null: false,
                  comment: "simples / presumido / real"
        t.integer :crt, default: 1, comment: "1=Simples Nacional (codigo CRT da NF-e)"

        # Numeracao e serie (por estabelecimento; SEFAZ exige independente)
        t.integer :serie_nfe,  default: 1
        t.integer :serie_nfce, default: 1
        t.integer :proximo_numero_nfe,  default: 1
        t.integer :proximo_numero_nfce, default: 1

        # NFC-e: CSC (Codigo de Seguranca do Contribuinte) e id do token, por UF.
        # O CSC em si e sensivel; guardar valor real via credentials na Parte B.
        t.string  :csc_id, limit: 10, comment: "identificador do CSC (idToken)"
        t.string  :csc_token, limit: 64, comment: "CSC — mover para credentials na Parte B"

        # Certificado A1: apenas referencia/metadados. O arquivo .pfx NUNCA no repo.
        t.string  :certificado_nome, limit: 120
        t.date    :certificado_validade

        # Provedor escolhido (preenchido na Parte B; neutro por ora)
        t.string  :provedor, limit: 20, comment: "focus / brasilnfe (a definir)"

        t.boolean :ativo, default: true, null: false
        t.timestamps
      end

      add_index :fiscal_config, :cod_empresa, unique: true, name: "idx_fiscal_config_empresa"
    end
  end
end
