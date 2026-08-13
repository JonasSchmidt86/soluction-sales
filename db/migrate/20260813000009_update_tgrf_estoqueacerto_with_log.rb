class UpdateTgrfEstoqueacertoWithLog < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.tgrf_estoqueacerto()
          RETURNS trigger
          LANGUAGE 'plpgsql'
          COST 100
          VOLATILE NOT LEAKPROOF
      AS $BODY$
      DECLARE
          EXISTE           BIGINT;
          ITEMQUANTIDADE   NUMERIC(15,2);
          QTD_ANTES        NUMERIC(15,2);
          QTD_MOVIDA       NUMERIC(15,2);
      BEGIN

          ITEMQUANTIDADE = 0;
          QTD_ANTES = 0;

          -- =====================
          -- DELETE
          -- =====================
          IF TG_OP = 'DELETE' THEN

              SELECT COALESCE(COUNT(*),0) INTO EXISTE
                FROM EMPRESAPRODUTO
               WHERE COD_EMPRESA = OLD.COD_EMPRESA
                 AND COD_PRODUTO = OLD.COD_PRODUTO
                 AND COD_COR = OLD.COD_COR;

              ITEMQUANTIDADE = OLD.QUANTIDADE;

              IF COALESCE(EXISTE,0) > 0 THEN

                  SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                    FROM EMPRESAPRODUTO E
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  -- Tipo E (entrada): ao deletar, subtrai
                  IF OLD.TIPO = 'E' THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - ITEMQUANTIDADE,
                             DATAALTERACAO = DATE(CURRENT_DATE)
                       WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                         AND E.COD_COR = OLD.COD_COR
                         AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                      QTD_MOVIDA = 0 - ITEMQUANTIDADE;

                  -- Tipo S (saída): ao deletar, soma de volta
                  ELSIF OLD.TIPO = 'S' THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + ITEMQUANTIDADE,
                             DATAALTERACAO = DATE(CURRENT_DATE)
                       WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                         AND E.COD_COR = OLD.COD_COR
                         AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                      QTD_MOVIDA = ITEMQUANTIDADE;
                  END IF;

                  -- Log
                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'AJUSTE',
                      QTD_ANTES, QTD_MOVIDA, (QTD_ANTES + QTD_MOVIDA),
                      OLD.CODIGO, NULL, current_user, NULL,
                      'Delete acerto tipo ' || OLD.TIPO || ' - ' || COALESCE(OLD.DESCRICAO,'')
                  );

              ELSE
                  -- Produto não existia, cria com quantidade 0
                  INSERT INTO EMPRESAPRODUTO(
                      COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                      ultimocusto, valorvenda, dataalteracao)
                  VALUES (
                      OLD.COD_COR, OLD.COD_EMPRESA, OLD.COD_PRODUTO, 0, 0, 0,
                      0, 0, DATE(CURRENT_DATE));

                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'AJUSTE',
                      0, 0, 0,
                      OLD.CODIGO, NULL, current_user, NULL,
                      'Delete acerto - produto nao existia'
                  );
              END IF;

              RETURN OLD;

          -- =====================
          -- INSERT ou UPDATE
          -- =====================
          ELSE

              -- No UPDATE: desfaz o antigo e aplica o novo
              IF TG_OP = 'UPDATE' THEN
                  -- Primeiro desfaz o efeito do registro antigo
                  SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                    FROM EMPRESAPRODUTO E
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  IF OLD.TIPO = 'E' THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
                             DATAALTERACAO = DATE(CURRENT_DATE)
                       WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                         AND E.COD_COR = OLD.COD_COR
                         AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                  ELSIF OLD.TIPO = 'S' THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                             DATAALTERACAO = DATE(CURRENT_DATE)
                       WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                         AND E.COD_COR = OLD.COD_COR
                         AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                  END IF;
              END IF;

              ITEMQUANTIDADE = NEW.QUANTIDADE;

              SELECT COALESCE(COUNT(*),0) INTO EXISTE
                FROM EMPRESAPRODUTO
               WHERE COD_EMPRESA = NEW.COD_EMPRESA
                 AND COD_PRODUTO = NEW.COD_PRODUTO
                 AND COD_COR = NEW.COD_COR;

              IF COALESCE(EXISTE,0) = 0 THEN
                  INSERT INTO EMPRESAPRODUTO(
                      COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                      ultimocusto, valorvenda, dataalteracao)
                  VALUES (
                      NEW.COD_COR, NEW.COD_EMPRESA, NEW.COD_PRODUTO, 0, 0, 0,
                      0, 0, DATE(CURRENT_DATE));
              END IF;

              -- Captura quantidade antes de aplicar
              SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                FROM EMPRESAPRODUTO E
               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                 AND E.COD_COR = NEW.COD_COR
                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;

              IF NEW.TIPO = 'E' THEN
                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + ITEMQUANTIDADE,
                         DATAALTERACAO = DATE(CURRENT_DATE)
                   WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                     AND E.COD_COR = NEW.COD_COR
                     AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                  QTD_MOVIDA = ITEMQUANTIDADE;

              ELSIF NEW.TIPO = 'S' THEN
                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - ITEMQUANTIDADE,
                         DATAALTERACAO = DATE(CURRENT_DATE)
                   WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                     AND E.COD_COR = NEW.COD_COR
                     AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                  QTD_MOVIDA = 0 - ITEMQUANTIDADE;
              END IF;

              -- Log
              INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                  quantidade_antes, quantidade_movida, quantidade_depois,
                  cod_referencia, cod_item, usuario, cod_funcionario, observacao)
              VALUES (
                  NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, TG_OP, 'AJUSTE',
                  QTD_ANTES, QTD_MOVIDA, (QTD_ANTES + QTD_MOVIDA),
                  NEW.CODIGO, NULL, current_user, NULL,
                  CASE TG_OP
                      WHEN 'INSERT' THEN 'Acerto tipo ' || NEW.TIPO || ' - ' || COALESCE(NEW.DESCRICAO,'')
                      WHEN 'UPDATE' THEN 'Alteracao acerto tipo ' || NEW.TIPO || ' - ' || COALESCE(NEW.DESCRICAO,'')
                  END
              );

              RETURN NEW;
          END IF;

      END;
      $BODY$;

      -- Recria o trigger
      DROP TRIGGER IF EXISTS "UDPATE_ESTOQUE" ON public.acertosestoque;
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE" ON public.acertosestoque;

      CREATE TRIGGER "UPDATE_ESTOQUE"
          BEFORE INSERT OR DELETE OR UPDATE
          ON public.acertosestoque
          FOR EACH ROW
          EXECUTE FUNCTION public.tgrf_estoqueacerto();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE" ON public.acertosestoque;
      DROP FUNCTION IF EXISTS public.tgrf_estoqueacerto();
    SQL
  end
end
