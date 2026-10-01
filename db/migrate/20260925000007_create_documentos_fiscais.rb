class CreateDocumentosFiscais < ActiveRecord::Migration[7.1]
  def change
    # ============================================================
    # DOCUMENTO FISCAL
    # Registro de cada NF-e/NFC-e emitida (ou tentada). Maquina de estados:
    # rascunho -> enviada -> autorizada / rejeitada / denegada / cancelada.
    # Guarda chave, protocolo, XML e DANFE (base64) retornados pelo provedor.
    # ============================================================
    unless table_exists?(:documento_fiscal)
      create_table :documento_fiscal, primary_key: :cod_documento_fiscal do |t|
        t.bigint  :cod_empresa, null: false
        t.bigint  :cod_venda,   comment: "venda de origem (nil se NF avulsa)"

        t.integer :modelo,   null: false, comment: "55 (NF-e) ou 65 (NFC-e)"
        t.integer :serie
        t.integer :numero
        t.string  :natureza_operacao, limit: 60
        t.integer :finalidade, default: 1, comment: "1 normal, 4 devolucao..."
        t.string  :ambiente, limit: 12, default: "homologacao", null: false

        # Situacao
        t.string  :status, limit: 15, default: "rascunho", null: false,
                  comment: "rascunho/enviada/autorizada/rejeitada/denegada/cancelada/erro"
        t.string  :chave_acesso, limit: 44
        t.string  :protocolo, limit: 30
        t.integer :cod_status_sefaz
        t.string  :mensagem_sefaz, limit: 255

        # Arquivos (base64 retornado pelo provedor)
        t.text    :xml_base64
        t.text    :danfe_base64

        # Rastreio
        t.bigint  :cod_funcionario, comment: "quem emitiu"
        t.string  :provedor, limit: 20
        t.datetime :emitido_em

        t.timestamps

        t.index [:cod_empresa, :status], name: "idx_documento_fiscal_empresa_status"
        t.index [:cod_venda],    name: "idx_documento_fiscal_venda"
        t.index [:chave_acesso], name: "idx_documento_fiscal_chave"
      end
    end

    # ============================================================
    # EVENTOS DO DOCUMENTO (cancelamento, carta de correcao, etc.)
    # ============================================================
    unless table_exists?(:documento_fiscal_evento)
      create_table :documento_fiscal_evento, primary_key: :cod_documento_fiscal_evento do |t|
        t.bigint  :cod_documento_fiscal, null: false
        t.string  :tipo, limit: 30, null: false, comment: "cancelamento/carta_correcao/inutilizacao"
        t.string  :status, limit: 15, default: "pendente", null: false
        t.string  :protocolo, limit: 30
        t.string  :justificativa, limit: 255
        t.text    :xml_base64
        t.string  :mensagem_sefaz, limit: 255
        t.datetime :registrado_em
        t.timestamps

        t.index [:cod_documento_fiscal], name: "idx_doc_fiscal_evento_documento"
      end
    end
  end
end
