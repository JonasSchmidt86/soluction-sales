class AddOrigemToEstoqueTriggers < ActiveRecord::Migration[7.1]
  # Atualiza os 3 triggers de estoque para gravar tambem a origem do sistema
  # (WEB ou DESKTOP), lida da variavel de sessao app.origem.
  #
  # Estrategia: em vez de reescrever cada trigger inteiro, criamos uma funcao
  # auxiliar que preenche a coluna origem_sistema apos cada insercao no
  # estoque_logs feita na transacao atual. Isso evita duplicar o corpo enorme
  # dos triggers e mantem a mudanca isolada.
  #
  # A funcao le current_setting('app.origem') e atualiza as linhas de
  # estoque_logs recem inseridas que ainda estao com origem_sistema NULL.

  def up
    # Cria uma funcao trigger AFTER INSERT em estoque_logs que preenche
    # a origem_sistema com base na variavel de sessao.
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.tgrf_estoquelog_origem()
          RETURNS trigger
          LANGUAGE 'plpgsql'
      AS $BODY$
      DECLARE
          V_ORIGEM VARCHAR(15);
      BEGIN
          BEGIN
              V_ORIGEM = NULLIF(current_setting('app.origem', true), '');
          EXCEPTION WHEN OTHERS THEN
              V_ORIGEM = NULL;
          END;

          IF NEW.origem_sistema IS NULL THEN
              NEW.origem_sistema = COALESCE(V_ORIGEM, 'DESCONHECIDO');
          END IF;

          RETURN NEW;
      END;
      $BODY$;
    SQL

    execute <<-SQL
      DROP TRIGGER IF EXISTS tg_estoquelog_origem ON estoque_logs;
      CREATE TRIGGER tg_estoquelog_origem
          BEFORE INSERT ON estoque_logs
          FOR EACH ROW
          EXECUTE FUNCTION public.tgrf_estoquelog_origem();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS tg_estoquelog_origem ON estoque_logs;"
    execute "DROP FUNCTION IF EXISTS public.tgrf_estoquelog_origem();"
  end
end
