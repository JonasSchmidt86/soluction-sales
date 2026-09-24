class AddFiscalFieldsToProduto < ActiveRecord::Migration[7.1]
  # Roda fora da transacao DDL do Rails para que o lock_timeout tenha efeito
  # real em cada ALTER (dentro da transacao, o SET nao protege como esperado).
  disable_ddl_transaction!

  def change
    # Evita travar a producao: se a tabela estiver com lock preso (ex: uma
    # transacao "idle in transaction" segurando 'produto'), cada ALTER desiste
    # em 5s em vez de bloquear todas as queries da tabela indefinidamente.
    # A migration e idempotente (unless column_exists?), entao pode ser
    # reexecutada ate concluir.
    execute "SET lock_timeout = '5s'"

    # Campos fiscais do PRODUTO (usados na emissao de saida)
    # origem: origem da mercadoria (0=nacional, 1=importacao direta, etc) - 1 digito
    # gtin:   codigo de barras (EAN/GTIN) - ate 14 digitos
    # csosn:  situacao tributaria no Simples Nacional (ex: 102, 500) - definido pelo contador
    add_column :produto, :origem, :string, limit: 1 unless column_exists?(:produto, :origem)
    add_column :produto, :gtin, :string, limit: 14 unless column_exists?(:produto, :gtin)
    add_column :produto, :csosn, :string, limit: 4 unless column_exists?(:produto, :csosn)

    # Guardar tambem no produtoxml o que veio do fornecedor (rastreabilidade do de-para)
    add_column :produtoxml, :origem, :string, limit: 1 unless column_exists?(:produtoxml, :origem)
    add_column :produtoxml, :gtin, :string, limit: 14 unless column_exists?(:produtoxml, :gtin)

    # Log de mudancas de dados fiscais do produto (opcao 1: atualiza sempre + registra quando muda)
    unless table_exists?(:produto_fiscal_logs)
      create_table :produto_fiscal_logs do |t|
        t.bigint  :cod_produto, null: false
        t.bigint  :cod_empresa
        t.bigint  :cod_pessoa,  comment: "fornecedor (emitente da nota)"
        t.string  :numeronf,    limit: 20, comment: "numero da NF que originou a mudanca"
        t.string  :campo,       null: false, limit: 20, comment: "campo alterado: ncm, origem, gtin, cest"
        t.string  :valor_antigo, limit: 20
        t.string  :valor_novo,   limit: 20
        t.datetime :created_at,  null: false

        t.index [:cod_produto], name: "idx_produto_fiscal_logs_produto"
        t.index [:campo],       name: "idx_produto_fiscal_logs_campo"
        t.index [:created_at],  name: "idx_produto_fiscal_logs_data"
      end
    end
  end
end
