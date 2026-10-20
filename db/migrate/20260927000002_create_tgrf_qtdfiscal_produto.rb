class CreateTgrfQtdfiscalProduto < ActiveRecord::Migration[7.1]
  # Trigger NOVA e INDEPENDENTE (nao altera a trigger de compra existente) que
  # mantem o estoque fiscal CONSOLIDADO por produto em fiscal_produto.qtd_fiscal.
  #
  # Regras (Etapa 6 do fiscal_produto):
  #  - Observa itemcompra (AFTER INSERT/UPDATE/DELETE).
  #  - So age quando a compra tem NF real (numeronf > 0) E a empresa tem
  #    fiscal_config ativo (so controla estoque fiscal quem tem o modulo).
  #  - qtd_fiscal e por PRODUTO (soma todas as cores): a trigger ignora cod_cor.
  #  - Cria o registro fiscal_produto se nao existir (qtd_fiscal inicial).
  #  - INSERT soma, DELETE subtrai, UPDATE ajusta pela diferenca de quantidade.
  #
  # A qtdfiscal POR COR em empresaproduto e a trigger de compra atual NAO sao
  # tocadas — esta trigger e um controle paralelo, consolidado por produto.
  def up
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
          -- Empresa/produto de referencia (NEW no insert/update, OLD no delete).
          IF TG_OP = 'DELETE' THEN
              V_EMPRESA := OLD.COD_EMPRESA;
              V_PRODUTO := OLD.COD_PRODUTO;
          ELSE
              V_EMPRESA := NEW.COD_EMPRESA;
              V_PRODUTO := NEW.COD_PRODUTO;
          END IF;

          -- So controla estoque fiscal se a empresa tem fiscal_config ativo.
          SELECT EXISTS (
              SELECT 1 FROM FISCAL_CONFIG
               WHERE COD_EMPRESA = V_EMPRESA AND ATIVO = TRUE
          ) INTO V_TEM_FISCAL;

          IF NOT V_TEM_FISCAL THEN
              RETURN COALESCE(NEW, OLD);
          END IF;

          -- Calcula o delta de quantidade a aplicar, so quando a compra tem NF
          -- real (numeronf > 0). Sem NF, nao movimenta estoque fiscal.
          IF TG_OP = 'INSERT' THEN
              IF COALESCE(NEW.NUMERONF,0) > 0 THEN
                  V_DELTA := COALESCE(NEW.QUANTIDADE,0);
              END IF;

          ELSIF TG_OP = 'DELETE' THEN
              IF COALESCE(OLD.NUMERONF,0) > 0 THEN
                  V_DELTA := -COALESCE(OLD.QUANTIDADE,0);
              END IF;

          ELSIF TG_OP = 'UPDATE' THEN
              -- Ajuste pela diferenca, considerando a NF de cada lado.
              V_DELTA := (CASE WHEN COALESCE(NEW.NUMERONF,0) > 0 THEN COALESCE(NEW.QUANTIDADE,0) ELSE 0 END)
                       - (CASE WHEN COALESCE(OLD.NUMERONF,0) > 0 THEN COALESCE(OLD.QUANTIDADE,0) ELSE 0 END);
          END IF;

          IF V_DELTA = 0 THEN
              RETURN COALESCE(NEW, OLD);
          END IF;

          -- Upsert: cria o fiscal_produto se nao existir (qtd_fiscal = delta),
          -- senao soma o delta. qtd_fiscal e por (empresa, produto) — sem cor.
          INSERT INTO FISCAL_PRODUTO (COD_EMPRESA, COD_PRODUTO, QTD_FISCAL, ATIVO, CREATED_AT, UPDATED_AT)
          VALUES (V_EMPRESA, V_PRODUTO, V_DELTA, TRUE, NOW(), NOW())
          ON CONFLICT (COD_EMPRESA, COD_PRODUTO) DO UPDATE
             SET QTD_FISCAL = COALESCE(FISCAL_PRODUTO.QTD_FISCAL,0) + V_DELTA,
                 UPDATED_AT = NOW();

          RETURN COALESCE(NEW, OLD);
      END;
      $BODY$;
    SQL

    execute <<-SQL
      DROP TRIGGER IF EXISTS tgr_qtdfiscal_produto ON itemcompra;
      CREATE TRIGGER tgr_qtdfiscal_produto
          AFTER INSERT OR UPDATE OR DELETE ON itemcompra
          FOR EACH ROW
          EXECUTE FUNCTION public.tgrf_qtdfiscal_produto();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS tgr_qtdfiscal_produto ON itemcompra;"
    execute "DROP FUNCTION IF EXISTS public.tgrf_qtdfiscal_produto();"
  end
end
