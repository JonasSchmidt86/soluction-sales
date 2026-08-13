class UpdateTgrfEstoquecompraWithLog < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION public.tgrf_estoquecompra()
          RETURNS trigger
          LANGUAGE 'plpgsql'
          COST 100
          VOLATILE NOT LEAKPROOF
      AS $BODY$
      DECLARE
          EXISTE              BIGINT;
          MARGEM              BIGINT;
          GRUPOMARGEM         BIGINT;
          PORCENTAGEM_MARGEM  NUMERIC(15,5);
          NOVO_VALOR_VENDA    NUMERIC(15,2);
          PRFRETE             NUMERIC(15,5);
          CUSTOFINAL          NUMERIC(15,2);
          VALORFRETE          NUMERIC(15,2);
          VALORCOMPRA         NUMERIC(15,2);
          ITEMQUANTIDADE      NUMERIC(15,2);
          QTD_ANTES           NUMERIC(15,2);
      BEGIN

          -- =====================
          -- DELETE
          -- =====================
          IF TG_OP = 'DELETE' THEN

              SELECT COUNT(*) INTO EXISTE
                FROM EMPRESAPRODUTO
               WHERE COD_EMPRESA = OLD.COD_EMPRESA
                 AND COD_PRODUTO = OLD.COD_PRODUTO
                 AND COD_COR = OLD.COD_COR;

              IF EXISTE > 0 THEN
                  -- Captura quantidade antes
                  SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                    FROM EMPRESAPRODUTO E
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  UPDATE EMPRESAPRODUTO AS E
                     SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
                         QTDFISCAL = CASE
                             WHEN OLD.NUMERONF > 0 THEN COALESCE(E.QTDFISCAL,0) - OLD.QUANTIDADE
                             ELSE E.QTDFISCAL
                         END
                   WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
                     AND E.COD_COR = OLD.COD_COR
                     AND E.COD_EMPRESA = OLD.COD_EMPRESA;

                  -- Log
                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, custofinal, usuario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'COMPRA',
                      QTD_ANTES, (0 - OLD.QUANTIDADE), (QTD_ANTES - OLD.QUANTIDADE),
                      OLD.COD_COMPRA, OLD.COD_ITEM, NULL, current_user,
                      'Delete item compra'
                  );
              ELSE
                  INSERT INTO EMPRESAPRODUTO (
                      COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                      ultimocusto, valorvenda, dataalteracao
                  )
                  VALUES (
                      OLD.COD_COR, OLD.COD_EMPRESA, OLD.COD_PRODUTO, (0 - OLD.VALORUNITARIO),
                      (0 - OLD.QUANTIDADE), 0, OLD.VALORUNITARIO, 0, DATE(CURRENT_DATE)
                  );

                  -- Log
                  INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                      quantidade_antes, quantidade_movida, quantidade_depois,
                      cod_referencia, cod_item, custofinal, usuario, observacao)
                  VALUES (
                      OLD.COD_EMPRESA, OLD.COD_PRODUTO, OLD.COD_COR, 'DELETE', 'COMPRA',
                      0, (0 - OLD.QUANTIDADE), (0 - OLD.QUANTIDADE),
                      OLD.COD_COMPRA, OLD.COD_ITEM, NULL, current_user,
                      'Delete item compra - produto novo criado com qtd negativa'
                  );
              END IF;

              RETURN OLD;

          -- =====================
          -- INSERT ou UPDATE
          -- =====================
          ELSE
              -- Determinar a diferença de quantidade
              IF TG_OP = 'UPDATE' THEN
                  ITEMQUANTIDADE = NEW.QUANTIDADE - OLD.QUANTIDADE;
              ELSE
                  ITEMQUANTIDADE = NEW.QUANTIDADE;
              END IF;

              -- Inicializa variáveis
              PRFRETE = 0;
              CUSTOFINAL = 0;
              VALORFRETE = 0;
              VALORCOMPRA = 0;

              -- Cálculo do custo final unitário
              CUSTOFINAL = NEW.VALORUNITARIO
                         + (COALESCE(NEW.VALORST,0) / NEW.QUANTIDADE)
                         + (COALESCE(NEW.VALOR_FRETE,0) / NEW.QUANTIDADE)
                         + (NEW.IPI / NEW.QUANTIDADE);

              -- Busca valor do frete da compra
              SELECT COALESCE(F.VALOR,0) INTO VALORFRETE
                FROM FRETE F
               WHERE F.COD_FRETE = (SELECT C.COD_FRETE
                                      FROM COMPRA C
                                     WHERE C.COD_COMPRA = NEW.COD_COMPRA);

              -- Aplica proporcional do frete se existir
              IF COALESCE(VALORFRETE,0) > 0 THEN
                  SELECT C.VALORTOTAL INTO VALORCOMPRA
                    FROM COMPRA C
                   WHERE C.COD_COMPRA = NEW.COD_COMPRA;

                  IF COALESCE(VALORCOMPRA,0) > 0 THEN
                      PRFRETE = ((VALORFRETE / VALORCOMPRA) + 1);
                      CUSTOFINAL = CUSTOFINAL * PRFRETE;
                  END IF;
              END IF;

              -- Atualiza o campo custofinal_unitario no próprio item de compra
              NEW.custofinal_unitario = CUSTOFINAL;

              -- Busca margem do produto ou grupo
              SELECT COD_MARGEM, GRUPO INTO MARGEM, GRUPOMARGEM
                FROM PRODUTO
               WHERE COD_PRODUTO = NEW.COD_PRODUTO;

              -- Verifica margem fixa do produto
              IF COALESCE(MARGEM,0) > 0 THEN
                  SELECT MARGEMPRODUTO INTO PORCENTAGEM_MARGEM
                    FROM PARAMETROS
                   WHERE ATIVO = TRUE
                     AND COD_PARAMETRO = MARGEM;

              -- Senão, verifica margem do grupo
              ELSIF COALESCE(GRUPOMARGEM,0) > 0 THEN
                  SELECT COD_MARGEM INTO MARGEM
                    FROM GRUPO
                   WHERE COD_GRUPO = GRUPOMARGEM;

                  IF MARGEM IS NOT NULL THEN
                      SELECT MARGEMPRODUTO INTO PORCENTAGEM_MARGEM
                        FROM PARAMETROS
                       WHERE ATIVO = TRUE
                         AND COD_PARAMETRO = MARGEM;
                  END IF;
              END IF;

              -- Calcula valor de venda
              IF COALESCE(PORCENTAGEM_MARGEM,0) > 0 THEN
                  NOVO_VALOR_VENDA = CUSTOFINAL * ((PORCENTAGEM_MARGEM / 100) + 1);
              ELSE
                  NOVO_VALOR_VENDA = CUSTOFINAL;
              END IF;

              -- Verifica se já existe na EMPRESAPRODUTO
              SELECT COUNT(*) INTO EXISTE
                FROM EMPRESAPRODUTO
               WHERE COD_EMPRESA = NEW.COD_EMPRESA
                 AND COD_PRODUTO = NEW.COD_PRODUTO
                 AND COD_COR = NEW.COD_COR;

              -- Se não existir, insere
              IF EXISTE = 0 THEN
                  INSERT INTO EMPRESAPRODUTO (
                      COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
                      ultimocusto, valorvenda, dataalteracao
                  )
                  VALUES (
                      NEW.COD_COR, NEW.COD_EMPRESA, NEW.COD_PRODUTO, COALESCE(CUSTOFINAL,0), 0, 0,
                      COALESCE(CUSTOFINAL,0), COALESCE(NOVO_VALOR_VENDA,0), DATE(CURRENT_DATE)
                  );
              END IF;

              -- Captura quantidade antes do update
              SELECT COALESCE(E.QUANTIDADE,0) INTO QTD_ANTES
                FROM EMPRESAPRODUTO E
               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                 AND E.COD_COR = NEW.COD_COR
                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;

              -- Atualiza estoque e custos
              UPDATE EMPRESAPRODUTO AS E
                 SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + ITEMQUANTIDADE,
                     ULTIMOCUSTO = COALESCE(CUSTOFINAL,0),
                     CUSTOMEDIO = COALESCE(((CUSTOFINAL + E.CUSTOMEDIO) / 2), 0),
                     VALORVENDA = COALESCE(NOVO_VALOR_VENDA,0),
                     QTDFISCAL = CASE
                         WHEN NEW.NUMERONF > 0 THEN COALESCE(E.QTDFISCAL,0) + ITEMQUANTIDADE
                         ELSE E.QTDFISCAL
                     END,
                     DATAALTERACAO = DATE(CURRENT_DATE)
               WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
                 AND E.COD_COR = NEW.COD_COR
                 AND E.COD_EMPRESA = NEW.COD_EMPRESA;

              -- Log
              INSERT INTO estoque_logs (cod_empresa, cod_produto, cod_cor, operacao, origem,
                  quantidade_antes, quantidade_movida, quantidade_depois,
                  cod_referencia, cod_item, custofinal, usuario, observacao)
              VALUES (
                  NEW.COD_EMPRESA, NEW.COD_PRODUTO, NEW.COD_COR, TG_OP, 'COMPRA',
                  QTD_ANTES, ITEMQUANTIDADE, (QTD_ANTES + ITEMQUANTIDADE),
                  NEW.COD_COMPRA, NEW.COD_ITEM, CUSTOFINAL, current_user,
                  CASE TG_OP
                      WHEN 'INSERT' THEN 'Novo item compra'
                      WHEN 'UPDATE' THEN 'Alteracao item compra (diff: ' || ITEMQUANTIDADE || ')'
                  END
              );

              RETURN NEW;
          END IF;

      END;
      $BODY$;
    SQL
  end

  def down
    # Rollback volta para a versão sem log (migration 20260813000002)
  end
end
