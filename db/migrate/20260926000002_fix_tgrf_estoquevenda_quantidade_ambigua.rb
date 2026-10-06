class FixTgrfEstoquevendaQuantidadeAmbigua < ActiveRecord::Migration[7.1]
  # Versiona a correcao do trigger tgrf_estoquevenda que ate entao foi aplicada
  # MANUALMENTE no banco (prod + local). O bug: no ramo de UPDATE de "alteracao
  # so de quantidade", a variavel PL/pgSQL QUANTIDADE tinha o mesmo nome da
  # coluna, deixando "COALESCE(E.QUANTIDADE,0) - QUANTIDADE" ambiguo (PG aborta
  # com AmbiguousColumn). Corrigido usando (NEW.QUANTIDADE - OLD.QUANTIDADE).
  #
  # Sem esta migration, um ambiente novo (schema:load / setup do zero) traria a
  # versao antiga com o bug. Aqui recriamos a FUNCTION (CREATE OR REPLACE, a
  # partir do dump da versao corrigida em db/triggers/) e garantimos o TRIGGER.
  #
  # disable_ddl_transaction! + lock_timeout: evita travar indefinidamente se um
  # cliente externo deixar transacao idle (risco conhecido neste banco).
  disable_ddl_transaction!

  TRIGGER_SQL_PATH = Rails.root.join("db", "triggers", "tgrf_estoquevenda.sql")

  def up
    execute "SET lock_timeout = '10s'"

    # Recria a function com a versao corrigida (idempotente via CREATE OR REPLACE).
    execute(File.read(TRIGGER_SQL_PATH))

    # Garante o trigger na itemvenda (idempotente: dropa e recria).
    execute <<~SQL
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE" ON public.itemvenda;
      CREATE TRIGGER "UPDATE_ESTOQUE"
        BEFORE INSERT OR DELETE OR UPDATE ON public.itemvenda
        FOR EACH ROW EXECUTE FUNCTION public.tgrf_estoquevenda();
    SQL
  end

  def down
    # Nao reverter: a versao anterior continha o bug de ambiguidade.
    say "Rollback nao aplicavel (voltaria a introduzir a coluna ambigua)."
  end
end
