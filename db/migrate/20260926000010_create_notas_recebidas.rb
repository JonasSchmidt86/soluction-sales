class CreateNotasRecebidas < ActiveRecord::Migration[7.1]
  # Notas fiscais de ENTRADA (emitidas por fornecedores CONTRA o CNPJ da empresa),
  # obtidas automaticamente da SEFAZ via Brasil NFe (ObterNotasFiscais, entradas).
  # E o "radar" de notas recebidas: existe mesmo antes de o XML/compra existir,
  # e guarda o status SEFAZ para detectar cancelamento posterior.
  def change
    create_table :nota_recebida, primary_key: :cod_nota_recebida do |t|
      t.bigint  :cod_empresa, null: false, comment: "empresa destinataria (dona da nota recebida)"
      t.string  :chave_acesso, limit: 44, null: false, comment: "chave de acesso da NF-e (44 digitos)"
      t.bigint  :cod_pessoa, comment: "fornecedor emitente (resolvido pelo CNPJ do emit)"

      t.integer :modelo, comment: "55 NF-e / 65 NFC-e"
      t.string  :numero, limit: 20
      t.string  :serie, limit: 10
      t.datetime :data_emissao
      t.decimal :valor_total, precision: 15, scale: 2

      t.string  :emitente_cnpj, limit: 20
      t.string  :emitente_nome, limit: 120
      t.string  :natureza_operacao, limit: 120
      t.integer :tipo_nf, comment: "tpNF: 0 entrada / 1 saida (sob a otica do emitente)"

      t.string  :transportadora_nome, limit: 120
      t.string  :transportadora_cnpj, limit: 20

      # Situacao na SEFAZ: autorizada / cancelada / denegada / desconhecida.
      t.string  :status_sefaz, limit: 15, default: "desconhecida", null: false
      t.datetime :status_sincronizado_em, comment: "ultima consulta de status na SEFAZ"

      # Integracao no sistema: quando vira uma Compra. nil = ainda nao importada.
      t.bigint  :cod_compra, comment: "compra gerada na importacao (nil = nao integrada)"
      t.bigint  :xml_file_id, comment: "XmlFile com o XML baixado (reaproveita infra atual)"

      t.string  :origem, limit: 15, default: "sefaz", comment: "sefaz (automatico) / upload (manual)"

      t.timestamps
    end

    add_index :nota_recebida, [:cod_empresa, :chave_acesso], unique: true,
              name: "idx_nota_recebida_empresa_chave"
    add_index :nota_recebida, [:cod_empresa, :status_sefaz], name: "idx_nota_recebida_empresa_status"
    add_index :nota_recebida, :cod_compra, name: "idx_nota_recebida_compra"
  end
end
