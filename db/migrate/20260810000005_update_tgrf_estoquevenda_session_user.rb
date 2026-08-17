class UpdateTgrfEstoquevendaSessionUser < ActiveRecord::Migration[7.1]
  def up
    # Atualiza apenas o trecho que busca o cod_funcionario na function de venda
    # para usar a variável de sessão app.current_funcionario com fallback para o cod_funcionario da venda
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
          QTD_ANTES        NUMERIC(15,2);
          QTD_ANTES_DEST   NUMERIC(15,2);
          LOG_ORIGEM       VARCHAR(15);
          LOG_OBS          VARCHAR(255);
          V_COD_FUNCIONARIO BIGINT;
      BEGIN

          VL_VENDA = 0;

          -- Buscar cod_funcionario da sessão (quem está logado agora)
          -- Fallback: se não tiver sessão, pega da venda
          BEGIN
              V_COD_FUNCIONARIO = NULLIF(current_setting('app.current_funcionario', true), '')::BIGINT;
          EXCEPTION WHEN OTHERS THEN
              V_COD_FUNCIONARIO = NULL;
          END;

          IF V_COD_FUNCIONARIO IS NULL THEN
              IF TG_OP = 'DELETE' THEN
                  SELECT V.COD_FUNCIONARIO INTO V_COD_FUNCIONARIO
                    FROM VENDA V WHERE V.COD_VENDA = OLD.COD_VENDA AND V.COD_EMPRESA = OLD.COD_EMPRESA;
              ELSE
                  SELECT V.COD_FUNCIONARIO INTO V_COD_FUNCIONARIO
                    FROM VENDA V WHERE V.COD_VENDA = NEW.COD_VENDA AND V.COD_EMPRESA = NEW.COD_EMPRESA;
              END IF;
          END IF;

          -- =====================
          -- DELETE
          -- =====================
          IF TG_OP = 'DELETE' THEN

              IF COALESCE(OLD.cancelado, FALSE) = TRUE THEN
                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'VENDA',
                      0, 0, 0,
                      OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                      'Delete item ja cancelado - estoque nao alterado'
                  );
                  RETURN OLD;
              END IF;

              SELECT V.COD_EMPRESA_TRANSFERIDA, V.TIPO
                INTO COD_EMP_TRANS, TIPOVENDA
                FROM VENDA AS V
               WHERE V.COD_VENDA = OLD.COD_VENDA
                 AND V.COD_EMPRESA = OLD.COD_EMPRESA;

              SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                FROM EMPRESAPRODUTO E
               WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                 AND E.COD_COR = OLD.COD_COR
                 AND E.COD_EMPRESA = OLD.COD_EMPRESA;

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

                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'VENDA',
                      QTD_ANTES, OLD.QUANTIDADE, (QTD_ANTES + OLD.QUANTIDADE),
                      OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                      'Delete item venda - estoque devolvido'
                  );

              ELSIF TIPOVENDA = 'T' THEN
                  SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES_DEST
                    FROM EMPRESAPRODUTO E
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = COD_EMP_TRANS;

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

                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'TRANSFERENCIA',
                      QTD_ANTES, OLD.QUANTIDADE, (QTD_ANTES + OLD.QUANTIDADE),
                      OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                      'Delete transferencia - devolvido na origem'
                  );
                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      COD_EMP_TRANS, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'TRANSFERENCIA',
                      QTD_ANTES_DEST, (0 - OLD.QUANTIDADE), (QTD_ANTES_DEST - OLD.QUANTIDADE),
                      OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                      'Delete transferencia - subtraido no destino'
                  );

              ELSIF TIPOVENDA = 'D' THEN
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

                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'DEVOLUCAO',
                      QTD_ANTES, (0 - OLD.QUANTIDADE), (QTD_ANTES - OLD.QUANTIDADE),
                      OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                      'Delete item devolucao - cancelou a devolucao'
                  );
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

              SELECT COALESCE(COUNT(*),0), COALESCE(SUM(VALORVENDA),0) INTO EXISTE, VL_VENDA
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

              -- =====================
              -- INSERT
              -- =====================
              IF TG_OP = 'INSERT' THEN

                  SELECT COALESCE(SUM(E.ultimocusto),0) INTO CUSTO
                    FROM EMPRESAPRODUTO AS E
                   WHERE E.COD_EMPRESA = NEW.COD_EMPRESA
                     AND E.COD_PRODUTO = NEW.COD_PRODUTO
                     AND E.COD_COR = NEW.COD_COR;

                  NEW.valororiginal = CUSTO;

                  SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                    FROM EMPRESAPRODUTO E
                   WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                     AND E.COD_COR = NEW.COD_COR
                     AND E.COD_EMPRESA = NEW.COD_EMPRESA;

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

                      INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                          quantidade_antes, quantidade_movida, quantidade_depois,
                          cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                      VALUES (
                          NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, 'INSERT', 'VENDA',
                          QTD_ANTES, (0 - NEW.QUANTIDADE), (QTD_ANTES - NEW.QUANTIDADE),
                          NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                          'Nova venda - saida estoque'
                      );

                  ELSIF TIPOVENDA = 'T' THEN
                      SELECT COUNT(*) INTO EXISTE
                        FROM EMPRESAPRODUTO
                       WHERE COD_EMPRESA = COD_EMP_TRANS
                         AND COD_PRODUTO = NEW.COD_PRODUTO
                         AND COD_COR = NEW.COD_COR;

                      IF COALESCE(EXISTE,0) = 0 THEN
                          INSERT INTO EMPRESAPRODUTO(
                              COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                              ultimocusto, valorvenda, dataalteracao)
                          VALUES (
                              NEW.COD_COR, COD_EMP_TRANS, NEW.COD_PRODUTO, NEW.VALORUNITARIO, 0, 0,
                              NEW.VALORUNITARIO, VL_VENDA, DATE(CURRENT_DATE));
                      END IF;

                      SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES_DEST
                        FROM EMPRESAPRODUTO E
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = COD_EMP_TRANS;

                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                             DATAALTERACAO = CURRENT_DATE
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                      UPDATE EMPRESAPRODUTO AS E
                         SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + NEW.QUANTIDADE,
                             ULTIMOCUSTO = NEW.VALORUNITARIO,
                             CUSTOMEDIO = ((NEW.VALORUNITARIO + COALESCE(E.CUSTOMEDIO,0)) / 2),
                             VALORVENDA = VL_VENDA,
                             DATAALTERACAO = CURRENT_DATE
                       WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                         AND E.COD_COR = NEW.COD_COR
                         AND E.COD_EMPRESA = COD_EMP_TRANS;

                      INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                          quantidade_antes, quantidade_movida, quantidade_depois,
                          cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                      VALUES (
                          NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, 'INSERT', 'TRANSFERENCIA',
                          QTD_ANTES, (0 - NEW.QUANTIDADE), (QTD_ANTES - NEW.QUANTIDADE),
                          NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                          'Transferencia - saida da origem'
                      );
                      INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                          quantidade_antes, quantidade_movida, quantidade_depois,
                          cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                      VALUES (
                          COD_EMP_TRANS, NEW.COD_PRODUTO, NEW.COD_COR, 'INSERT', 'TRANSFERENCIA',
                          QTD_ANTES_DEST, NEW.QUANTIDADE, (QTD_ANTES_DEST + NEW.QUANTIDADE),
                          NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                          'Transferencia - entrada no destino'
                      );

                  ELSIF TIPOVENDA = 'D' THEN
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

                      INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                          quantidade_antes, quantidade_movida, quantidade_depois,
                          cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                      VALUES (
                          NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, 'INSERT', 'DEVOLUCAO',
                          QTD_ANTES, NEW.QUANTIDADE, (QTD_ANTES + NEW.QUANTIDADE),
                          NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                          'Devolucao - entrada estoque'
                      );
                  END IF;

                  RETURN NEW;

              -- =====================
              -- UPDATE
              -- =====================
              ELSIF TG_OP = 'UPDATE' THEN

                  SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                    FROM EMPRESAPRODUTO E
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  -- 1) CANCELAMENTO
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

                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'CANCELAMENTO', 'VENDA',
                              QTD_ANTES, OLD.QUANTIDADE, (QTD_ANTES + OLD.QUANTIDADE),
                              OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Cancelamento venda - estoque devolvido'
                          );

                      ELSIF TIPOVENDA = 'T' THEN
                          SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES_DEST
                            FROM EMPRESAPRODUTO E
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = COD_EMP_TRANS;

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

                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'CANCELAMENTO', 'TRANSFERENCIA',
                              QTD_ANTES, OLD.QUANTIDADE, (QTD_ANTES + OLD.QUANTIDADE),
                              OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Cancelamento transferencia - devolvido na origem'
                          );
                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              COD_EMP_TRANS, OLD.COD_PRODUTO, OLD.COD_COR, 'CANCELAMENTO', 'TRANSFERENCIA',
                              QTD_ANTES_DEST, (0 - OLD.QUANTIDADE), (QTD_ANTES_DEST - OLD.QUANTIDADE),
                              OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Cancelamento transferencia - subtraido no destino'
                          );

                      ELSIF TIPOVENDA = 'D' THEN
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

                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'CANCELAMENTO', 'DEVOLUCAO',
                              QTD_ANTES, (0 - OLD.QUANTIDADE), (QTD_ANTES - OLD.QUANTIDADE),
                              OLD.COD_VENDA, OLD.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Cancelamento devolucao - estoque subtraido'
                          );
                      END IF;

                  -- 2) NÃO cancelado: mudança de produto, cor ou quantidade
                  ELSIF COALESCE(NEW.cancelado, FALSE) = FALSE THEN

                      IF OLD.cod_produto IS DISTINCT FROM NEW.cod_produto THEN
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;

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

                          SELECT COALESCE(SUM(E.ultimocusto),0) INTO CUSTO
                            FROM EMPRESAPRODUTO AS E
                           WHERE E.COD_EMPRESA = NEW.COD_EMPRESA
                             AND E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR;
                          NEW.valororiginal = CUSTO;

                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

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

                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'UPDATE', 'VENDA',
                              QTD_ANTES, OLD.QUANTIDADE, (QTD_ANTES + OLD.QUANTIDADE),
                              NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Troca produto - devolvido produto antigo'
                          );
                          SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES_DEST
                            FROM EMPRESAPRODUTO E
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, 'UPDATE', 'VENDA',
                              (QTD_ANTES_DEST + NEW.QUANTIDADE), (0 - NEW.QUANTIDADE), QTD_ANTES_DEST,
                              NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Troca produto - subtraido produto novo'
                          );

                      ELSIF OLD.cod_cor IS DISTINCT FROM NEW.cod_cor THEN
                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + OLD.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                             AND E.COD_COR = OLD.COD_COR
                             AND E.COD_EMPRESA = OLD.COD_EMPRESA;

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

                          SELECT COALESCE(SUM(E.ultimocusto),0) INTO CUSTO
                            FROM EMPRESAPRODUTO AS E
                           WHERE E.COD_EMPRESA = NEW.COD_EMPRESA
                             AND E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR;
                          NEW.valororiginal = CUSTO;

                          SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES_DEST
                            FROM EMPRESAPRODUTO E
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - NEW.QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

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

                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'UPDATE', 'VENDA',
                              QTD_ANTES, OLD.QUANTIDADE, (QTD_ANTES + OLD.QUANTIDADE),
                              NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Troca cor - devolvido cor antiga'
                          );
                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, 'UPDATE', 'VENDA',
                              (QTD_ANTES_DEST + NEW.QUANTIDADE), (0 - NEW.QUANTIDADE), QTD_ANTES_DEST,
                              NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Troca cor - subtraido cor nova'
                          );

                      ELSIF OLD.quantidade IS DISTINCT FROM NEW.quantidade THEN
                          QUANTIDADE = NEW.QUANTIDADE - OLD.QUANTIDADE;

                          UPDATE EMPRESAPRODUTO AS E
                             SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - QUANTIDADE,
                                 DATAALTERACAO = CURRENT_DATE
                           WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                             AND E.COD_COR = NEW.COD_COR
                             AND E.COD_EMPRESA = NEW.COD_EMPRESA;

                          IF COALESCE(NEW.numeronf,0) > 0 THEN
                              UPDATE EMPRESAPRODUTO AS E
                                 SET QTDFISCAL = COALESCE(E.QTDFISCAL,0) - QUANTIDADE
                               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                                 AND E.COD_COR = NEW.COD_COR
                                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;
                          END IF;

                          INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                              quantidade_antes, quantidade_movida, quantidade_depois,
                              cod_referencia, cod_item, usuario, cod_funcionario, observacao)
                          VALUES (
                              NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, 'UPDATE', 'VENDA',
                              QTD_ANTES, (0 - QUANTIDADE), (QTD_ANTES - QUANTIDADE),
                              NEW.COD_VENDA, NEW.COD_ITEM, current_user, V_COD_FUNCIONARIO,
                              'Alteracao quantidade (diff: ' || QUANTIDADE || ')'
                          );
                      END IF;
                  END IF;

                  RETURN NEW;
              END IF;
          END IF;
      END;
      $BODY$;
    SQL
  end

  def down
    # Rollback para versão anterior (busca direto da venda sem sessão)
  end
end
