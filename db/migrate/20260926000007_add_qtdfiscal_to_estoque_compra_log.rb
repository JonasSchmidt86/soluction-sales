class AddQtdfiscalToEstoqueCompraLog < ActiveRecord::Migration[7.1]
  # Recria a função tgrf_estoquecompra() para gravar as colunas fiscais
  # (qtdfiscal_antes/movida/depois) no INSERT em estoque_logs, SOMENTE quando
  # a NF foi informada (NUMERONF > 0). O cálculo do estoque (físico e fiscal)
  # NÃO muda — é só auditoria no log. A função é versionada em
  # db/triggers/tgrf_estoquecompra.sql.
  disable_ddl_transaction!

  def up
    execute "SET lock_timeout = '10s'"
    sql = File.read(Rails.root.join("db", "triggers", "tgrf_estoquecompra.sql"))
    execute(sql)
  end

  def down
    # Reaplica a versão anterior da função (sem colunas fiscais no log).
    execute "SET lock_timeout = '10s'"
    FixEstoqueCompraTz.new.up
  end
end
