class CreateTgrfEstoquevendaFunction < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.tgrf_estoquevenda()
          RETURNS trigger
          LANGUAGE 'plpgsql'
          COST 100
          VOLATILE NOT LEAKPROOF
      AS $BODY$
      DECLARE
          QUANTIDADE       NUMERIC(15,2);
          CUSTO            NUMERIC(15,2);
          COD_EMP_TRANS    BIGINT;
          EXISTE           BIGINT;
          TIPOVENDA        CHARACTER varying(1);
          VL_VENDA         NUMERIC(18,2);
      BEGIN

          VL_VENDA = 0;

          -- =====================
          -- DELETE
          -- =====================
          IF TG_OP = 'DELETE' THEN

              -- Busca tipo da venda para saber se é transferência
              SELECT V.COD_EMPRESA_TRANSFERIDA, V.TIPO
                INTO COD_EMP_TRANS, TIPOVENDA
                FROM VENDA AS V
               WHERE V.COD_VENDA = OLD.COD_VENDA
                 AND V.COD_EMPRESA = OLD.COD_EMPRESA;

              IF TIPOVENDA = 'V' THEN
                  -- Venda normal: devolve estoque na empresa
                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                         DATAALTERACAO = CURRENT_DATE
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  -- Devolve qtdfiscal se tinha NF
                  IF COALESCE(OLD.numeronf,0) > 0 THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) + OLD.QUANTIDADE
                       WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                         AND E.COD_COR = OLD.COD_COR
                         AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                  END IF;

              ELSIF TIPOVENDA = 'T' THEN
                  -- Transferência: devolve na origem e subtrai no destino
                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                         DATAALTERACAO = CURRENT_DATE
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
                         DATAALTERACAO = CURRENT_DATE
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = COD_EMP_TRANS;

              ELSIF TIPOVENDA = 'D' THEN
                  -- Devolução: ao deletar item de devolução, subtrai (cancela a devolução)
                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
                         DATAALTERACAO = CURRENT_DATE
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  IF COALESCE(OLD.numeronf,0) > 0 THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - OLD.QUANTIDADE
                       WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                         AND E.COD_COR = OLD.COD_COR
                         AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                  END IF;
              END IF;

              RETURN OLD;

          -- =====================
          -- INSERT ou UPDATE
          -- =====================
          ELSE

              SELECT V.COD_EMPRESA_TRANSFERIDA, V.TIPO
                INTO COD_EMP_TRANS, TIPOVENDA
                FROM VENDA AS V
               WHERE V.COD_VENDA = NEW.COD_VENDA
                 AND V.COD_EMPRESA = NEW.COD_EMPRESA;

              -- Verifica se já existe esse produto na empresa
              SELECT COALESCE(COUNT(*),0), COALESCE(SUM(VALORVENDA),0) INTO EXISTE, VL_VENDA
                FROM EMPRESAPRODUTO
               WHERE COD_EMPRESA = NEW.COD_EMPRESA
                 AND COD_PRODUTO = NEW.COD_PRODUTO
                 AND COD_COR = NEW.COD_COR;

              -- Se o produto não existir, cria (cor nova sem estoque)
              IF COALESCE(EXISTE,0) = 0 THEN
                  INSERT INTO EMPRESAPRODUTO(
                      COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                      ultimocusto, valorvenda, dataalteracao)
                  VALUES (
                      NEW.COD_COR, NEW.COD_EMPRESA, NEW.COD_PRODUTO, 0, 0, 0,
                      0, NEW.VALORUNITARIO, DATE(CURRENT_DATE));
              END IF;

              -- =====================
              -- INSERT
              -- =====================
              IF TG_OP = 'INSERT' THEN

                  -- Grava o ultimo custo no item
                  SELECT COALESCE(SUM(E.ultimocusto),0) INTO CUSTO
                    FROM EMPRESAPRODUTO AS E
                   WHERE E.COD_EMPRESA = NEW.COD_EMPRESA
                     AND E.COD_PRODUTO = NEW.COD_PRODUTO
                     AND E.COD_COR = NEW.COD_COR;

                  NEW.valororiginal = CUSTO;

                  IF TIPOVENDA = 'V' THEN
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                             DATAALTERACAO = CURRENT_DATE
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                      IF COALESCE(NEW.numeronf,0) > 0 THEN
                          UPDATE EMPRESAPRODUTO AS E
                             SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - NEW.QUANTIDADE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                      END IF;

                  ELSIF TIPOVENDA = 'T' THEN
                      -- Verifica se existe o produto na empresa destino
                      SELECT COUNT(*) INTO EXISTE
                        FROM EMPRESAPRODUTO
                       WHERE COD_EMPRESA = COD_EMP_TRANS
                         AND COD_PRODUTO = NEW.COD_PRODUTO
                         AND COD_COR = NEW.COD_COR;

                      -- Se não existir, insere na empresa destino
                      IF COALESCE(EXISTE,0) = 0 THEN
                          INSERT INTO EMPRESAPRODUTO(
                              COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                              ultimocusto, valorvenda, dataalteracao)
                          VALUES (
                              NEW.COD_COR, COD_EMP_TRANS, NEW.COD_PRODUTO, NEW.VALORUNITARIO, 0, 0,
                              NEW.VALORUNITARIO, VL_VENDA, DATE(CURRENT_DATE));
                      END IF;

                      -- Subtrai da empresa origem
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                             DATAALTERACAO = CURRENT_DATE
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                      -- Soma na empresa destino
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + NEW.QUANTIDADE,
                             ULTIMOCUSTO = NEW.VALORUNITARIO,
                             CUSTOMEDIO = ((NEW.VALORUNITARIO + COALESCE(E.CUSTOMEDIO,0)) / 2),
                             VALORVENDA = VL_VENDA,
                             DATAALTERACAO = CURRENT_DATE
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = COD_EMP_TRANS;

                  ELSIF TIPOVENDA = 'D' THEN
                      -- Devolução: soma de volta no estoque
                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + NEW.QUANTIDADE,
                             DATAALTERACAO = CURRENT_DATE
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                      IF COALESCE(NEW.numeronf,0) > 0 THEN
                          UPDATE EMPRESAPRODUTO AS E
                             SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) + NEW.QUANTIDADE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                      END IF;
                  END IF;

                  RETURN NEW;

              -- =====================
              -- UPDATE
              -- =====================
              ELSIF TG_OP = 'UPDATE' THEN

                  -- 1) CANCELAMENTO: devolve o estoque usando OLD.quantidade
                  IF NEW.cancelado = TRUE AND OLD.cancelado IS DISTINCT FROM TRUE THEN

                      IF TIPOVENDA = 'V' THEN
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                          IF COALESCE(OLD.numeronf,0) > 0 THEN
                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) + OLD.QUANTIDADE
                               WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                                 AND E.COD_COR = OLD.COD_COR
                                 AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                          END IF;

                      ELSIF TIPOVENDA = 'T' THEN
                          -- Devolve na origem
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                          -- Subtrai no destino
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = COD_EMP_TRANS;

                      ELSIF TIPOVENDA = 'D' THEN
                          -- Cancelar devolução = tirar de volta
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                          IF COALESCE(OLD.numeronf,0) > 0 THEN
                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - OLD.QUANTIDADE
                               WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                                 AND E.COD_COR = OLD.COD_COR
                                 AND E.COD_EMPRESA = OLD.COD_EMPRESA;
                          END IF;
                      END IF;

                  -- 2) NÃO cancelado: mudança de produto, cor ou quantidade
                  ELSIF COALESCE(NEW.cancelado, FALSE) = FALSE THEN

                      -- Se trocou o PRODUTO inteiro
                      IF OLD.cod_produto IS DISTINCT FROM NEW.cod_produto THEN
                          -- Devolve estoque do produto antigo
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                          -- Garante que o novo produto/cor exista
                          SELECT COUNT(*) INTO EXISTE
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
                                  0, NEW.VALORUNITARIO, DATE(CURRENT_DATE));
                          END IF;

                          -- Subtrai estoque do produto novo
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                          -- Ajusta qtdfiscal se tinha NF
                          IF COALESCE(NEW.numeronf,0) > 0 THEN
                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) + OLD.QUANTIDADE
                               WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                                 AND E.COD_COR = OLD.COD_COR
                                 AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - NEW.QUANTIDADE
                               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                                 AND E.COD_COR = NEW.COD_COR
                                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                          END IF;

                      -- Se trocou só a COR (mesmo produto)
                      ELSIF OLD.cod_cor IS DISTINCT FROM NEW.cod_cor THEN
                          -- Devolve na cor antiga
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                          -- Garante que a nova cor exista
                          SELECT COUNT(*) INTO EXISTE
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
                                  0, NEW.VALORUNITARIO, DATE(CURRENT_DATE));
                          END IF;

                          -- Subtrai na cor nova
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                          -- Ajusta qtdfiscal
                          IF COALESCE(NEW.numeronf,0) > 0 THEN
                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) + OLD.QUANTIDADE
                               WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                                 AND E.COD_COR = OLD.COD_COR
                                 AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - NEW.QUANTIDADE
                               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                                 AND E.COD_COR = NEW.COD_COR
                                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                          END IF;

                      -- Se mudou só a QUANTIDADE (mesmo produto, mesma cor)
                      ELSIF OLD.quantidade IS DISTINCT FROM NEW.quantidade THEN
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - (NEW.QUANTIDADE - OLD.QUANTIDADE),
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                          IF COALESCE(NEW.numeronf,0) > 0 THEN
                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - (NEW.QUANTIDADE - OLD.QUANTIDADE)
                               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                                 AND E.COD_COR = NEW.COD_COR
                                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                          END IF;
                      END IF;

                  END IF;

                  RETURN NEW;
              END IF;

          END IF;

          RETURN NULL;
      END;
      $BODY$;

      ALTER FUNCTION public.tgrf_estoquevenda() OWNER TO postgres;

      -- Recria o trigger (dropa o antigo com typo e cria com nome correto)
      DROP TRIGGER IF EXISTS "UDPATE_ESTOQUE" ON public.itemvenda;
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE" ON public.itemvenda;

      CREATE TRIGGER "UPDATE_ESTOQUE"
          BEFORE INSERT OR DELETE OR UPDATE
          ON public.itemvenda
          FOR EACH ROW
          EXECUTE FUNCTION public.tgrf_estoquevenda();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS "UDPATE_ESTOQUE" ON public.itemvenda;
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE" ON public.itemvenda;
      DROP TRIGGER IF EXISTS "UPDATE_ESTOQUE_VENDA" ON public.itemvenda;
      DROP FUNCTION IF EXISTS public.tgrf_estoquevenda();
    SQL
  end
end
