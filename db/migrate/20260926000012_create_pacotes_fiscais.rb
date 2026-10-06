class CreatePacotesFiscais < ActiveRecord::Migration[7.1]
  # Historico de pacotes fiscais gerados (zip de XML/PDF ou Excel) por periodo.
  # O arquivo e salvo (Active Storage) para baixar/reenviar sem chamar o provedor
  # de novo. Guarda tambem se/quando foi enviado ao contador.
  def change
    create_table :pacote_fiscal, primary_key: :cod_pacote_fiscal do |t|
      t.bigint   :cod_empresa, null: false
      t.date     :periodo_inicio, null: false
      t.date     :periodo_fim, null: false
      t.integer  :tipo_arquivo, default: 1, comment: "0 PDF / 1 XML / 2 Excel"
      t.integer  :tipo_nota, default: 1, comment: "1 saidas / 2 entradas / 3 ambos"
      t.boolean  :incluir_cce, default: false
      t.string   :nome_arquivo, limit: 150
      t.string   :mime, limit: 60
      t.integer  :quantidade, comment: "qtd de notas no pacote (Quantidade da API)"
      t.bigint   :tamanho_bytes
      t.datetime :gerado_em
      t.datetime :enviado_contador_em
      t.string   :email_destino, limit: 120
      t.bigint   :cod_funcionario, comment: "quem gerou"
      t.timestamps
    end

    add_index :pacote_fiscal, [:cod_empresa, :periodo_inicio, :periodo_fim],
              name: "idx_pacote_fiscal_empresa_periodo"
  end
end
