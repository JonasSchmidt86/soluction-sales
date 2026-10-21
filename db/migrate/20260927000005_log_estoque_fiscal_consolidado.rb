class LogEstoqueFiscalConsolidado < ActiveRecord::Migration[7.1]
  # Registro de LOG das movimentacoes do estoque fiscal consolidado
  # (fiscal_produto.qtd_fiscal), reusando a tabela estoque_logs. Consolida numa
  # unica migration:
  #   1) cod_cor passa a aceitar NULL  -> log consolidado por produto (sem cor).
  #   2) Padroniza o campo `origem` (que passa a indicar a TABELA afetada; a
  #      `operacao` ja diz o que aconteceu):
  #        empresaproduto.qtdfiscal -> 'EMPRESA_PRODUTO'
  #        fiscal_produto.qtd_fiscal -> 'FISCAL_PRODUTO'
  #      Tambem corrige eventual historico com os nomes antigos.
  #   3) Recria a trigger tgrf_qtdfiscal_produto para, alem do upsert, GRAVAR o
  #      log consolidado na entrada de compra, capturando quem fez
  #      (app.current_funcionario / fallback compra.cod_funcionario) e de onde
  #      veio (app.origem_sistema / fallback 'TRIGGER'), igual a tgrf_estoquecompra.
  #
  # A gravacao do log na SAIDA (venda/avulsa) fica no Fiscal::EstoqueFiscalService.
  def up
    change_column_null :estoque_logs, :cod_cor, true

    # Historico eventualmente gravado com nomes antigos (idempotente).
    execute "UPDATE estoque_logs SET origem = 'EMPRESA_PRODUTO' WHERE origem = 'NFE_FISCAL'"
    execute "UPDATE estoque_logs SET origem = 'FISCAL_PRODUTO'  WHERE origem = 'FISCAL_PROD'"

    recriar_trigger_com_log
  end

  def down
    # Volta a trigger a versao sem log (a original, so upsert).
    recriar_trigger_sem_log

    # Reverte nomes de origem (se nao houver consolidados que impecam o NOT NULL).
    execute "UPDATE estoque_logs SET origem = 'NFE_FISCAL'  WHERE origem = 'EMPRESA_PRODUTO'"
    execute "UPDATE estoque_logs SET origem = 'FISCAL_PROD' WHERE origem = 'FISCAL_PRODUTO'"

    if select_value("SELECT COUNT(*) FROM estoque_logs WHERE cod_cor IS NULL").to_i.zero?
      change_column_null :estoque_logs, :cod_cor, false
    else
      say "Mantido cod_cor nullable: existem logs consolidados (cod_cor IS NULL)."
    end
  end

  private

  def recriar_trigger_com_log
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.tgrf_qtdfiscal_produto()
          RETURNS trigger
          LANGUAGE 'plpgsql'
      AS $BODY$
      DECLARE
          V_EMPRESA  BIGINT;
          V_PRODUTO  BIGINT;
          V_DELTA    NUMERIC(18,2) := 0;
          V_TEM_FISCAL BOOLEAN;
          V_ANTES    NUMERIC(18,2);
          V_DEPOIS   NUMERIC(18,2);
          V_REF      BIGINT;
          V_COD_FUNCIONARIO BIGINT;
          V_ORIGEM_SISTEMA  VARCHAR;
      BEGIN
          IF TG_OP = 'DELETE' THEN
              V_EMPRESA := OLD.COD_EMPRESA; V_PRODUTO := OLD.COD_PRODUTO; V_REF := OLD.COD_COMPRA;
          ELSE
              V_EMPRESA := NEW.COD_EMPRESA; V_PRODUTO := NEW.COD_PRODUTO; V_REF := NEW.COD_COMPRA;
          END IF;

          SELECT EXISTS (SELECT 1 FROM FISCAL_CONFIG WHERE COD_EMPRESA = V_EMPRESA AND ATIVO = TRUE)
            INTO V_TEM_FISCAL;
          IF NOT V_TEM_FISCAL THEN RETURN COALESCE(NEW, OLD); END IF;

          IF TG_OP = 'INSERT' THEN
              IF COALESCE(NEW.NUMERONF,0) > 0 THEN V_DELTA := COALESCE(NEW.QUANTIDADE,0); END IF;
          ELSIF TG_OP = 'DELETE' THEN
              IF COALESCE(OLD.NUMERONF,0) > 0 THEN V_DELTA := -COALESCE(OLD.QUANTIDADE,0); END IF;
          ELSIF TG_OP = 'UPDATE' THEN
              V_DELTA := (CASE WHEN COALESCE(NEW.NUMERONF,0) > 0 THEN COALESCE(NEW.QUANTIDADE,0) ELSE 0 END)
                       - (CASE WHEN COALESCE(OLD.NUMERONF,0) > 0 THEN COALESCE(OLD.QUANTIDADE,0) ELSE 0 END);
          END IF;

          IF V_DELTA = 0 THEN RETURN COALESCE(NEW, OLD); END IF;

          -- Quem fez: sessao (app.current_funcionario); fallback na compra.
          BEGIN
              V_COD_FUNCIONARIO := NULLIF(current_setting('app.current_funcionario', true), '')::BIGINT;
          EXCEPTION WHEN OTHERS THEN V_COD_FUNCIONARIO := NULL;
          END;
          IF V_COD_FUNCIONARIO IS NULL THEN
              SELECT c.cod_funcionario INTO V_COD_FUNCIONARIO FROM compra c WHERE c.cod_compra = V_REF;
          END IF;

          -- De onde veio: sessao (app.origem_sistema); fallback 'TRIGGER'.
          BEGIN
              V_ORIGEM_SISTEMA := NULLIF(current_setting('app.origem_sistema', true), '');
          EXCEPTION WHEN OTHERS THEN V_ORIGEM_SISTEMA := NULL;
          END;
          V_ORIGEM_SISTEMA := COALESCE(V_ORIGEM_SISTEMA, 'TRIGGER');

          SELECT COALESCE(QTD_FISCAL,0) INTO V_ANTES FROM FISCAL_PRODUTO
           WHERE COD_EMPRESA = V_EMPRESA AND COD_PRODUTO = V_PRODUTO;
          V_ANTES := COALESCE(V_ANTES, 0);

          INSERT INTO FISCAL_PRODUTO (COD_EMPRESA, COD_PRODUTO, QTD_FISCAL, ATIVO, CREATED_AT, UPDATED_AT)
          VALUES (V_EMPRESA, V_PRODUTO, V_DELTA, TRUE, NOW(), NOW())
          ON CONFLICT (COD_EMPRESA, COD_PRODUTO) DO UPDATE
             SET QTD_FISCAL = COALESCE(FISCAL_PRODUTO.QTD_FISCAL,0) + V_DELTA, UPDATED_AT = NOW()
          RETURNING QTD_FISCAL INTO V_DEPOIS;

          -- LOG consolidado: cod_cor NULO, origem = tabela afetada (FISCAL_PRODUTO).
          BEGIN
              INSERT INTO ESTOQUE_LOGS
                  (COD_EMPRESA, COD_PRODUTO, COD_COR, OPERACAO, ORIGEM,
                   QTDFISCAL_ANTES, QTDFISCAL_MOVIDA, QTDFISCAL_DEPOIS,
                   COD_REFERENCIA, COD_FUNCIONARIO, USUARIO, ORIGEM_SISTEMA,
                   OBSERVACAO, CREATED_AT)
              VALUES
                  (V_EMPRESA, V_PRODUTO, NULL,
                   CASE WHEN V_DELTA >= 0 THEN 'ENTRADA_FISCAL' ELSE 'ESTORNO_FISCAL' END,
                   'FISCAL_PRODUTO',
                   V_ANTES, V_DELTA, V_DEPOIS,
                   V_REF, V_COD_FUNCIONARIO, current_user, V_ORIGEM_SISTEMA,
                   'Compra - estoque fiscal consolidado (fiscal_produto)',
                   NOW());
          EXCEPTION WHEN OTHERS THEN NULL; -- log e auditoria; nao aborta o estoque
          END;

          RETURN COALESCE(NEW, OLD);
      END;
      $BODY$;
    SQL
  end

  def recriar_trigger_sem_log
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.tgrf_qtdfiscal_produto()
          RETURNS trigger
          LANGUAGE 'plpgsql'
      AS $BODY$
      DECLARE
          V_EMPRESA  BIGINT;
          V_PRODUTO  BIGINT;
          V_DELTA    NUMERIC(18,2) := 0;
          V_TEM_FISCAL BOOLEAN;
      BEGIN
          IF TG_OP = 'DELETE' THEN
              V_EMPRESA := OLD.COD_EMPRESA; V_PRODUTO := OLD.COD_PRODUTO;
          ELSE
              V_EMPRESA := NEW.COD_EMPRESA; V_PRODUTO := NEW.COD_PRODUTO;
          END IF;
          SELECT EXISTS (SELECT 1 FROM FISCAL_CONFIG WHERE COD_EMPRESA = V_EMPRESA AND ATIVO = TRUE) INTO V_TEM_FISCAL;
          IF NOT V_TEM_FISCAL THEN RETURN COALESCE(NEW, OLD); END IF;
          IF TG_OP = 'INSERT' THEN
              IF COALESCE(NEW.NUMERONF,0) > 0 THEN V_DELTA := COALESCE(NEW.QUANTIDADE,0); END IF;
          ELSIF TG_OP = 'DELETE' THEN
              IF COALESCE(OLD.NUMERONF,0) > 0 THEN V_DELTA := -COALESCE(OLD.QUANTIDADE,0); END IF;
          ELSIF TG_OP = 'UPDATE' THEN
              V_DELTA := (CASE WHEN COALESCE(NEW.NUMERONF,0) > 0 THEN COALESCE(NEW.QUANTIDADE,0) ELSE 0 END)
                       - (CASE WHEN COALESCE(OLD.NUMERONF,0) > 0 THEN COALESCE(OLD.QUANTIDADE,0) ELSE 0 END);
          END IF;
          IF V_DELTA = 0 THEN RETURN COALESCE(NEW, OLD); END IF;
          INSERT INTO FISCAL_PRODUTO (COD_EMPRESA, COD_PRODUTO, QTD_FISCAL, ATIVO, CREATED_AT, UPDATED_AT)
          VALUES (V_EMPRESA, V_PRODUTO, V_DELTA, TRUE, NOW(), NOW())
          ON CONFLICT (COD_EMPRESA, COD_PRODUTO) DO UPDATE
             SET QTD_FISCAL = COALESCE(FISCAL_PRODUTO.QTD_FISCAL,0) + V_DELTA, UPDATED_AT = NOW();
          RETURN COALESCE(NEW, OLD);
      END;
      $BODY$;
    SQL
  end
end
