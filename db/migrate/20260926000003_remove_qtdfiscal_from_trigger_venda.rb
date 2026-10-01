class RemoveQtdfiscalFromTriggerVenda < ActiveRecord::Migration[7.1]
  # Remove o controle de qtdfiscal (estoque FISCAL) da trigger de venda
  # (tgrf_estoquevenda). A partir daqui o qtdfiscal de SAÍDA passa a ser
  # controlado pelo RAILS no momento da emissão da NF (venda e avulsa),
  # respeitando regra_fiscal.controla_estoque.
  #
  # - Estoque FÍSICO (quantidade) continua 100% na trigger de venda.
  # - A trigger de COMPRA (tgrf_estoquecompra) NÃO é tocada: a ENTRADA de
  #   qtdfiscal continua por lá (o sistema legado de compras depende dela).
  #
  # O SQL vem de db/triggers/tgrf_estoquevenda.sql (versão já sem qtdfiscal).
  disable_ddl_transaction!

  TRIGGER_SQL_PATH = Rails.root.join("db", "triggers", "tgrf_estoquevenda.sql")

  def up
    execute "SET lock_timeout = '10s'"
    execute(File.read(TRIGGER_SQL_PATH))
    execute <<~SQL
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE" ON public.itemvenda;
      CREATE TRIGGER "UPDATE_ESTOQUE"
        BEFORE INSERT OR DELETE OR UPDATE ON public.itemvenda
        FOR EACH ROW EXECUTE FUNCTION public.tgrf_estoquevenda();
    SQL
  end

  def down
    say "Rollback manual: reaplicar a migration anterior do trigger (com qtdfiscal)."
  end
end
