
  
#   ALTER TABLE IF EXISTS public.lancamentoscaixa DROP CONSTRAINT IF EXISTS fk_caixa;
  
#   ALTER TABLE IF EXISTS public.caixa DROP CONSTRAINT IF EXISTS caixa_pkey;

#   ALTER TABLE IF EXISTS public.caixa ADD CONSTRAINT caixa_pkey PRIMARY KEY (id);


#   ALTER TABLE IF EXISTS public.lancamentoscaixa
#     ADD CONSTRAINT fk_caixa FOREIGN KEY (caixa_id)
#     REFERENCES public.caixa (id) MATCH SIMPLE
#     ON UPDATE NO ACTION
#     ON DELETE NO ACTION;

#   update lancamentoscaixa
#       set caixa_id = c.id
#     from caixa as c
#   where lancamentoscaixa.dataabertura = c.dataabertura;


#   alter table funcionarioempresa alter column cod_funcionarioempresa set default nextval('funcionario_codigo_seq'::regclass);
#   alter table funcionario alter column cod_funcionario set default nextval('funcionario_codigo_seq'::regclass);
#   ALTER TABLE Lancamentoscaixa ALTER COLUMN cod_lancamentocaixa SET DEFAULT nextval('lancamentocaixa_sequence'::regclass);


#   -- Alteração necessario para por o codigo do caixa no lugar da dataabertura


# CREATE OR REPLACE FUNCTION public.tgrf_updatecaixa()
# 	RETURNS trigger
# 	LANGUAGE 'plpgsql'
# 	COST 100
# 	VOLATILE NOT LEAKPROOF
# 	AS $BODY$

# 	DECLARE
# 		VLCAIXA       NUMERIC(15,2);
# 		VLBANCO       NUMERIC(15,2);
# 		TIPOVENDA     CHARACTER VARYING(1);
		
# 	BEGIN
# 	TIPOVENDA = NULL;

# 	IF  TG_OP = 'DELETE' THEN

# 		IF OLD.COD_BANCOCONTA IS NULL THEN

# 			IF OLD.TIPO = 'E' THEN

# 				SELECT C.VALORENTRADAS INTO VLCAIXA 
# 				FROM CAIXA AS C 
# 				WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				AND C.id = OLD.caixa_id;

# 				UPDATE CAIXA AS C
# 				SET VALORENTRADAS = (VLCAIXA - OLD.VALOR)
# 				WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				AND C.id = OLD.caixa_id;
				
# 				RETURN OLD;

# 			ELSIF OLD.TIPO = 'S' THEN

# 				SELECT C.VALORSAIDAS into VLCAIXA 
# 				FROM CAIXA AS C 
# 				WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				AND C.id = OLD.caixa_id;

# 				UPDATE CAIXA AS C
# 				SET VALORSAIDAS = (VLCAIXA - OLD.VALOR)
# 				WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				AND C.id = OLD.caixa_id;
				
# 				RETURN OLD;

# 			END IF;

# 		ELSIF OLD.COD_BANCOCONTA IS NOT NULL THEN

# 			IF OLD.TIPO = 'E' THEN

# 				-- SE FOR O PAGAMENTO DE UMA CONTA QUE NÃO PASSOU PELO CAIXA ELE NÃO ALTERA O CAIXA
# 				-- SE NÃO FOR UMA CONTA É UM LANCAMENTO DIVERSO QUE PODE TER SAIDO DO CAIXA ENTÃO ALTERA O CAIXA
# 				IF OLD.CAIXA_ID IS NOT NULL THEN

# 					SELECT B.ENTRADAS INTO VLBANCO 
# 					  FROM BANCOCONTA AS B
# 					WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 					  AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

# 					UPDATE BANCOCONTA AS B
# 					  SET ENTRADAS = ( VLBANCO - OLD.VALOR )
# 					WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 					  AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

# 					  -- sai do caixa e Entra no banco
# 					  SELECT C.VALORSAIDAS into VLCAIXA 
# 					  FROM CAIXA AS C 
# 					WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 					  AND C.DATAFECHAMENTO IS NULL;

# 					UPDATE CAIXA AS C
# 					  SET VALORSAIDAS = (VLCAIXA - OLD.VALOR)
# 					WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 					  AND C.DATAFECHAMENTO IS NULL;
					  
# 					  RETURN OLD;
					  
# 				END IF;


# 			ELSIF OLD.TIPO = 'S' THEN

# 				SELECT B.SAIDAS INTO VLBANCO 
# 				FROM BANCOCONTA AS B
# 				WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				AND b.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

# 				UPDATE BANCOCONTA AS B
# 				SET SAIDAS = ( VLBANCO - OLD.VALOR)
# 				WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

# 				-- SAI DA CONTA E VOLTA PRO CAIXA
# 				--SELECT C.VALORENTRADAS INTO VLCAIXA 
# 				--  FROM CAIXA AS C 
# 				-- WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				--   AND C.DATAFECHAMENTO IS NULL;

# 				--UPDATE CAIXA AS C
# 				--   SET VALORENTRADAS = (VLCAIXA - OLD.VALOR)
# 				-- WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				--   AND C.DATAFECHAMENTO IS NULL;

# 				RETURN OLD;
			
# 			END IF;
# 		END IF;

# 	ELSIF TG_OP = 'INSERT' THEN

# 		IF NEW.COD_TPHITORICO = 16 THEN
# 			RETURN NEW;
# 		END IF;

# 		IF NEW.COD_BANCOCONTA IS NULL THEN
# 			IF NEW.TIPO = 'E' THEN
				
# 				SELECT C.VALORENTRADAS INTO VLCAIXA 
# 				FROM CAIXA AS C
# 				WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND DATAFECHAMENTO IS NULL;

# 				UPDATE CAIXA AS C
# 				SET VALORENTRADAS = (VLCAIXA + NEW.VALOR)
# 				WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND DATAFECHAMENTO IS NULL;
				
# 				RETURN NEW;
				
# 			ELSIF NEW.TIPO = 'S' THEN
				
# 				SELECT C.VALORSAIDAS INTO VLCAIXA 
# 				  FROM CAIXA AS C 
# 				 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA
# 				   AND C.DATAFECHAMENTO IS NULL;

# 				UPDATE CAIXA AS C
# 				   SET VALORSAIDAS = (VLCAIXA + NEW.VALOR)
# 				 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND C.DATAFECHAMENTO IS NULL;
				
# 				RETURN NEW;
				
# 			END IF;

# 		ELSIF NEW.COD_BANCOCONTA IS NOT NULL THEN

# 			--select * from bancoconta where cod_bancoconta = ( select cod_bancoconta from empresa where cod_empresa = 2)
# 			IF NEW.TIPO = 'E' THEN
# 				-- LANCAMENTO DIVERSO SE ENTRADA NA CONTA SAI DO CAIXA PARA ENTRAR NA CONTA
# 				SELECT B.ENTRADAS INTO VLBANCO 
# 				FROM BANCOCONTA AS B
# 				WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

# 				UPDATE BANCOCONTA AS B
# 				SET ENTRADAS = ( VLBANCO + NEW.VALOR )
# 				WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

# 				IF NEW.COD_CONTASPAGREC IS NULL THEN

# 					-- ENTRA NA CONTA E SAI DO CAIXA
# 					SELECT C.VALORSAIDAS INTO VLCAIXA 
# 					FROM CAIXA AS C 
# 					WHERE C.COD_EMPRESA = NEW.COD_EMPRESA
# 					AND C.DATAFECHAMENTO IS NULL;

# 					UPDATE CAIXA AS C
# 					SET VALORSAIDAS = (VLCAIXA + NEW.VALOR)
# 					WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 					AND C.DATAFECHAMENTO IS NULL; 

# 				END IF;
			
# 				RETURN NEW;	

# 			ELSIF NEW.TIPO = 'S' THEN

# 				SELECT B.SAIDAS INTO VLBANCO 
# 				FROM BANCOCONTA AS B
# 				WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

# 				UPDATE BANCOCONTA AS B
# 				SET SAIDAS = ( VLBANCO + NEW.VALOR)
# 				WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

# 				-- SE FOR UMA SAIDA DA CONTA ENTRA NO CAIXA APENAS SE NAO FOR DE UMA CONTA
# 				IF NEW.COD_CONTASPAGREC IS NULL THEN					
# 					-- SAI DA CONTA E ENTRA NO CAIXA
# 					SELECT C.VALORENTRADAS INTO VLCAIXA 
# 					FROM CAIXA AS C
# 					WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 					AND C.DATAFECHAMENTO IS NULL;

# 					/*UPDATE CAIXA AS C
# 					SET VALORENTRADAS = (VLCAIXA + NEW.VALOR)
# 					WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 					AND C.DATAFECHAMENTO IS NULL;*/
# 				END IF;

# 				RETURN NEW;

# 			END IF;

# 		END IF;

# 	ELSIF TG_OP = 'UPDATE' THEN

# 		IF OLD.COD_BANCOCONTA IS NOT NULL THEN

# 		-- select * from bancoconta where cod_bancoconta = ( select cod_bancoconta from empresa where cod_empresa = 2)
# 			IF NEW.TIPO = 'E' THEN
# 			-- LANCAMENTO DIVERSO SE ENTRADA NA CONTA SAI DO CAIXA PARA ENTRAR NA CONTA

# 				IF NEW.COD_BANCOCONTA != OLD.COD_BANCOCONTA THEN
# 					-- SELECIONA PRIMEIRO O REGISTRO A ATUALIZAR PARA ALTERAR OS VALORES

# 					SELECT B.ENTRADAS INTO VLBANCO 
# 					FROM BANCOCONTA AS B	
# 					WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 					AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

# 					UPDATE BANCOCONTA AS B
# 					SET ENTRADAS = ( VLBANCO - OLD.VALOR )
# 					WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 					AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

# 					VLBANCO = 0;
# 					SELECT B.ENTRADAS INTO VLBANCO 
# 					FROM BANCOCONTA AS B	
# 					WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 					AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;

# 					UPDATE BANCOCONTA AS B
# 					SET ENTRADAS = ( VLBANCO + NEW.VALOR )
# 					WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 					AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;

# 				END IF;
# 				RETURN NEW;	

# 			ELSIF NEW.TIPO = 'S' THEN

# 				SELECT B.SAIDAS INTO VLBANCO 
# 				FROM BANCOCONTA AS B	
# 				WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

# 				UPDATE BANCOCONTA AS B
# 				SET SAIDAS = ( VLBANCO - OLD.VALOR )
# 				WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

# 				VLBANCO = 0;
# 				SELECT B.SAIDAS INTO VLBANCO 
# 				FROM BANCOCONTA AS B	
# 				WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;

# 				UPDATE BANCOCONTA AS B
# 				SET SAIDAS = ( VLBANCO + NEW.VALOR )
# 				WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;

# 				RETURN NEW;

# 			END IF;

# 		END IF;

# 		RETURN NULL;
		
# 	END IF;
# 	RETURN NULL;
# END

# $BODY$;


# ALTER TABLE IF EXISTS public.empresaproduto DROP CONSTRAINT IF EXISTS empresaproduto_pkey;
# ALTER TABLE IF EXISTS public.empresaproduto ADD CONSTRAINT empresaproduto_pkey PRIMARY KEY (id);


# UPDATE ITEMVENDA
# SET valororiginal = (
#     SELECT COALESCE(SUM(
#         CASE
#             WHEN EMPRESAPRODUTO.ultimocusto IS NOT NULL AND EMPRESAPRODUTO.ultimocusto > 0
#             THEN EMPRESAPRODUTO.ultimocusto
#             ELSE 0
#         END
#     ), 0)
#     FROM EMPRESAPRODUTO
#     WHERE EMPRESAPRODUTO.COD_PRODUTO = ITEMVENDA.COD_PRODUTO
#       AND EMPRESAPRODUTO.COD_COR = ITEMVENDA.COD_COR
# 	  AND EMPRESAPRODUTO.COD_EMPRESA = ITEMVENDA.COD_EMPRESA
# )
# WHERE (
#     valororiginal IS NULL OR valororiginal = 0
# ) AND EXISTS (
#     SELECT 1
#     FROM EMPRESAPRODUTO
#     WHERE EMPRESAPRODUTO.COD_PRODUTO = ITEMVENDA.COD_PRODUTO
#       AND EMPRESAPRODUTO.COD_COR = ITEMVENDA.COD_COR
# 	  AND EMPRESAPRODUTO.COD_EMPRESA = ITEMVENDA.COD_EMPRESA
# );

# -- fazer para adicionar o proximo id 
# -- select max(cod_lancamentocaixa) from lancamentoscaixa
# SELECT setval('lancamentocaixa_sequence', (select max(cod_lancamentocaixa)+1 from lancamentoscaixa));

# -- add sequence na tabela FRETE
# ALTER TABLE IF EXISTS public.frete
# 	ALTER COLUMN cod_frete SET DEFAULT nextval('frete_sequence');


# ---- TIGGER UPDATE ESTOQUE MUDADO PARA AFTER

# CREATE OR REPLACE TRIGGER update_estoque
# AFTER INSERT OR DELETE OR UPDATE 
# ON public.itemcompra
# FOR EACH ROW
# EXECUTE FUNCTION public.tgrf_estoquecompra();

# -- FUNCTION: public.tgrf_estoquecompra()

# -- DROP FUNCTION IF EXISTS public.tgrf_estoquecompra();


# -----------------

# CREATE OR REPLACE FUNCTION public.tgrf_estoquecompra()
#     RETURNS trigger
#     LANGUAGE 'plpgsql'
#     COST 100
#     VOLATILE NOT LEAKPROOF
# AS $BODY$
# DECLARE
#     EXISTE              BIGINT;   -- Se já existe o produto na tabela EMPRESAPRODUTO
#     MARGEM              BIGINT;   -- Margem do produto
#     GRUPOMARGEM         BIGINT;   -- Margem do grupo do produto
#     PORCENTAGEM_MARGEM  NUMERIC(15,5); -- Porcentagem da margem do produto ou grupo
#     NOVO_VALOR_VENDA    NUMERIC(15,2);
	
#     PRFRETE         	NUMERIC(15,5); 	-- EQUIVALENCIA DO FRETE 
# 	CUSTOFINAL 			NUMERIC(15,2); 	-- CUSTO FINAL DO PRODUTO COM FRETE
# 	VALORFRETE			NUMERIC(15,2); 	-- VALOR DO FRETE
# 	VALORCOMPRA			NUMERIC(15,2);    	-- VALOR TOTAL DA COMPRA
# 	ITEMQUANTIDADE		NUMERIC(15,2);    	-- QUANTIDADE DO ITEM BEGIN
	
# BEGIN
	
# 	-- RAISE NOTICE 'tipo %', TG_OP;
# 	-- RAISE NOTICE 'tipo %', COALESCE(VALORCOMPRA,0);

#     -- Verifica se a operação é DELETE
#     IF TG_OP = 'DELETE' THEN
#         -- Verifica se o item existe na tabela EMPRESAPRODUTO
#         SELECT COUNT(*) INTO EXISTE
#           FROM EMPRESAPRODUTO
#          WHERE COD_EMPRESA = OLD.COD_EMPRESA
#            AND COD_PRODUTO = OLD.COD_PRODUTO
#            AND COD_COR = OLD.COD_COR;

#         ITEMQUANTIDADE = OLD.QUANTIDADE;

#         -- Se o item existir, atualiza o estoque e a quantidade fiscal
#         IF EXISTE > 0 THEN
#             UPDATE EMPRESAPRODUTO AS E
#                SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) - OLD.QUANTIDADE,
#                    QTDFISCAL = CASE WHEN OLD.NUMERONF > 0 THEN COALESCE(E.QTDFISCAL,0) - OLD.QUANTIDADE ELSE E.QTDFISCAL END
#              WHERE E.COD_PRODUTO = OLD.COD_PRODUTO
#                AND E.COD_COR = OLD.COD_COR
#                AND E.COD_EMPRESA = OLD.COD_EMPRESA;
#         -- Se o item não existir, insere na tabela EMPRESAPRODUTO
#         ELSE
#             INSERT INTO EMPRESAPRODUTO (
#                 COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
#                 ultimocusto, valorvenda, dataalteracao
#             )
#             VALUES (
#                 OLD.COD_COR, OLD.COD_EMPRESA, OLD.COD_PRODUTO, (0 - OLD.VALORUNITARIO), 0, 0,
#                 OLD.VALORUNITARIO, 0, DATE(CURRENT_DATE)
#             );
#         END IF;

#         RETURN OLD;
#     -- Se a operação for INSERT ou UPDATE
#     ELSE
# 		------------------------
# 		PRFRETE = 0;
# 		CUSTOFINAL = 0;
# 		VALORFRETE = 0;
# 		VALORCOMPRA = 0;
# 		ITEMQUANTIDADE = NEW.QUANTIDADE;
# 		------------------------
#         -- Cálculos de custo final, valor do frete, etc.
		
# 		CUSTOFINAL = NEW.VALORUNITARIO + ((COALESCE(NEW.VALORST,0) / NEW.QUANTIDADE));
# 		CUSTOFINAL = CUSTOFINAL + ((COALESCE(NEW.VALOR_FRETE,0) / NEW.QUANTIDADE));
		
# 		-- SOMA O IPI JUNTO COM O CUSTO DO PRODUTO DIVIDIDO PELA QUANTIDADE 
# 		CUSTOFINAL = CUSTOFINAL + (NEW.IPI / NEW.QUANTIDADE);
		
# -- 		RAISE NOTICE 'valor-st 1= %', (COALESCE(NEW.VALORST,0));
# -- 		RAISE NOTICE 'ipi 1= %', new.ipi;
# -- 		RAISE NOTICE 'VALOR_FRETE 1= %', new.VALOR_FRETE;		
# -- 		RAISE NOTICE 'CUSTO 1= %', CUSTOFINAL;
		
#         SELECT COALESCE(VALOR,0) INTO VALORFRETE
# 		  FROM FRETE 
# 		 WHERE COD_FRETE = ( SELECT COD_FRETE 
# 				               FROM COMPRA
# 				              WHERE COD_COMPRA = NEW.COD_COMPRA );

# --         RAISE NOTICE 'frete 1= %', VALORFRETE;
		
# 		-- VERIFICA SE O VALOR DO FRETE E MAIOR QUE 0		
# 		IF COALESCE(VALORFRETE,0) > 0 THEN
		
# 			SELECT VALORTOTAL INTO VALORCOMPRA
# 			  FROM COMPRA WHERE COD_COMPRA = NEW.COD_COMPRA;
		
# 			-- VALORCOMPRA = COALESCE(NEW.VALORTOTAL,0);
			 
# --             RAISE NOTICE 'VALORCOMPRA %', COALESCE(VALORCOMPRA,0);

# 			-- VERIFICA O VALOR TOTAL DA COMPRA SE E MAIOR QUE ZERO
			
# 			IF COALESCE(VALORCOMPRA,0) > 0 THEN	
# 				PRFRETE = ((VALORFRETE / VALORCOMPRA)+1);
# 				CUSTOFINAL = CUSTOFINAL * PRFRETE;
# 			END IF;

#  			RAISE NOTICE 'PRFRETE %', COALESCE(PRFRETE,0);
# -- 			RAISE NOTICE 'CUSTOFINAL %', COALESCE(CUSTOFINAL,0);
# 		END IF;

#         -- calcula o valor de venda do produto
# 		-- pegar margem para calcular o valor de venda

# 		SELECT COD_MARGEM, GRUPO INTO MARGEM, GRUPOMARGEM 
# 		 FROM PRODUTO 
# 		WHERE COD_PRODUTO = NEW.COD_PRODUTO;
		
# 		-- verificar se o produto tem margem fixa
# 		IF COALESCE(MARGEM,0) > 0 THEN
		
# 			SELECT MARGEMPRODUTO INTO PORCENTAGEM_MARGEM 
# 		          FROM PARAMETROS 
# 		         WHERE ATIVO = TRUE 
# 		           AND COD_PARAMETRO = MARGEM;

# 		-- se não tiver margem verificar se o grupo dele tem margem           		
# 		ELSIF COALESCE(GRUPOMARGEM,0) > 0 THEN

# 			SELECT COD_MARGEM INTO MARGEM
# 			  FROM GRUPO 
# 			 WHERE COD_GRUPO = GRUPOMARGEM;
			 
# 			 IF MARGEM IS NOT NULL THEN
			 
# 				SELECT MARGEMPRODUTO INTO PORCENTAGEM_MARGEM 
# 				  FROM PARAMETROS 
# 				 WHERE ATIVO = TRUE 
# 				   AND COD_PARAMETRO = MARGEM;
# 			END IF;						 
# 		END IF;
		
		
# 		-- Lógica para calcular NOVO_VALOR_VENDA, PORCENTAGEM_MARGEM, etc.
# 		IF COALESCE(PORCENTAGEM_MARGEM,0) > 0 THEN
# 			NOVO_VALOR_VENDA = CUSTOFINAL * ((PORCENTAGEM_MARGEM/100)+1);
#         ELSE 
#             NOVO_VALOR_VENDA = CUSTOFINAL;
# 		END IF;
		
		
#         -- Verifica se o item existe na tabela EMPRESAPRODUTO
#         SELECT COUNT(*) INTO EXISTE
#           FROM EMPRESAPRODUTO
#         WHERE COD_EMPRESA = NEW.COD_EMPRESA
#           AND COD_PRODUTO = NEW.COD_PRODUTO
#           AND COD_COR = NEW.COD_COR;
# 		-- Se o item não existir, insere na tabela EMPRESAPRODUTO
#         IF EXISTE = 0 THEN
#             INSERT INTO EMPRESAPRODUTO (
#                 COD_COR, cod_empresa, cod_produto, customedio, quantidade, quantidademinima,
#                 ultimocusto, valorvenda, dataalteracao
#             )
#             VALUES (
#                 NEW.COD_COR, NEW.COD_EMPRESA, NEW.COD_PRODUTO, COALESCE(CUSTOFINAL,0), 0, 0,
#                 COALESCE(CUSTOFINAL,0), COALESCE(NOVO_VALOR_VENDA,0), DATE(CURRENT_DATE)
#             );
#         END IF;
		
#         -- Atualiza o estoque e outros campos na tabela EMPRESAPRODUTO
#         UPDATE EMPRESAPRODUTO AS E
# 		   SET QUANTIDADE = COALESCE(E.QUANTIDADE,0) + ITEMQUANTIDADE,
# 			   ULTIMOCUSTO = COALESCE(CUSTOFINAL,0),
# 			   CUSTOMEDIO = COALESCE(((CUSTOFINAL + CUSTOMEDIO)/2),0),
# 			   VALORVENDA = COALESCE(NOVO_VALOR_VENDA,0),
# 			   QTDFISCAL = CASE WHEN NEW.NUMERONF > 0 THEN COALESCE(E.QTDFISCAL,0) + ITEMQUANTIDADE ELSE E.QTDFISCAL END
#          WHERE E.COD_PRODUTO = NEW.COD_PRODUTO
#            AND E.COD_COR = NEW.COD_COR
#            AND E.COD_EMPRESA = NEW.COD_EMPRESA;

#         RETURN NEW;
#     END IF;
# END;
# $BODY$;

# -- ALTER TABLE IF EXISTS public.itemcompra ADD COLUMN valor_frete numeric(10,2) DEFAULT 0;

# update itemcompra
#    set valor_frete = 0
#    where valor_frete is null;

# ALTER TABLE IF EXISTS public.lancamentoscaixa
#     ALTER COLUMN cod_lancamentocaixa SET DEFAULT nextval('lancamentocaixa_sequence'::regclass);

# -- ver log postgres
# -- jonas@MacBook-Pro-de-Jonas ~ % tail -f /opt/homebrew/var/postgresql@14/pg_log/postgresql-*.log


# -- NÃO ESTAVA SOMANDO O CAIXA QUANDO A SAIDA ERA DO CAIXA OU ENTRADA
# -- FUNCTION: public.tgrf_updatecaixa()

# -- DROP FUNCTION IF EXISTS public.tgrf_updatecaixa();

# CREATE OR REPLACE FUNCTION public.tgrf_updatecaixa()
#     RETURNS trigger
#     LANGUAGE 'plpgsql'
#     COST 100
#     VOLATILE NOT LEAKPROOF
# AS $BODY$
# DECLARE
#         VLCAIXA       NUMERIC(15,2);
#         VLBANCO       NUMERIC(15,2);
#         TIPOVENDA     CHARACTER VARYING(1);
# 		CAIXA_ID      BIGINT;
# BEGIN
# 	TIPOVENDA = NULL;
# 	IF  TG_OP = 'DELETE' THEN

# 	SELECT ID INTO CAIXA_ID
# 	  FROM CAIXA 
# 	 WHERE COD_EMPRESA = OLD.COD_EMPRESA
# 	   AND DATAFECHAMENTO IS NULL;

# RAISE NOTICE 'Registro deletado: ID = %, Valor = %', OLD.cod_lancamentocaixa, OLD.valor;
# RAISE NOTICE 'CAIXA ID= %, Valor = %', CAIXA_ID, OLD.DATAABERTURA;

# 		IF OLD.COD_BANCOCONTA IS NULL THEN

# 			IF OLD.TIPO = 'E' THEN			
# 				SELECT C.VALORENTRADAS INTO VLCAIXA 
# 				  FROM CAIXA AS C 
# 				 WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				   AND C.ID = CAIXA_ID;
				
# 				UPDATE CAIXA AS C
# 				   SET VALORENTRADAS = (VLCAIXA - OLD.VALOR)
# 				 WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND C.ID = CAIXA_ID;
# 				   RETURN OLD;

# 			ELSIF OLD.TIPO = 'S' THEN
# 				SELECT C.VALORSAIDAS into VLCAIXA 
# 				  FROM CAIXA AS C 
# 				 WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				   AND C.ID = CAIXA_ID;
				   
# 				UPDATE CAIXA AS C
# 				   SET VALORSAIDAS = (VLCAIXA - OLD.VALOR)
# 				 WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND C.ID = CAIXA_ID;
# 				   RETURN OLD;

# 			END IF;
# 		ELSIF OLD.COD_BANCOCONTA IS NOT NULL THEN
# 			IF OLD.TIPO = 'E' THEN
# 				SELECT B.ENTRADAS INTO VLBANCO 
# 				  FROM BANCOCONTA AS B
# 				 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );
				
# 				UPDATE BANCOCONTA AS B
# 				   SET ENTRADAS = ( VLBANCO - OLD.VALOR )
# 				 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

# 				   -- sai do caixa e Entra no banco
# 				   SELECT C.VALORSAIDAS into VLCAIXA 
# 				  FROM CAIXA AS C 
# 				 WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				   AND C.DATAFECHAMENTO IS NULL;
				   
# 				UPDATE CAIXA AS C
# 				   SET VALORSAIDAS = (VLCAIXA - OLD.VALOR)
# 				 WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND C.DATAFECHAMENTO IS NULL;
# 				   RETURN OLD;

# --  980,  Q F LG
# --  860,  Q F LG				   
				   
# 			ELSIF OLD.TIPO = 'S' THEN
# 				SELECT B.SAIDAS INTO VLBANCO 
# 				  FROM BANCOCONTA AS B
# 				 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND b.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );
				
# 				UPDATE BANCOCONTA AS B
# 				   SET SAIDAS = ( VLBANCO - OLD.VALOR)
# 				 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

# 				-- SAI DA CONTA E VOLTA PRO CAIXA
# 				--SELECT C.VALORENTRADAS INTO VLCAIXA 
# 				--  FROM CAIXA AS C 
# 				-- WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
# 				--   AND C.DATAFECHAMENTO IS NULL;
				
# 				--UPDATE CAIXA AS C
# 				--   SET VALORENTRADAS = (VLCAIXA - OLD.VALOR)
# 				-- WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
# 				--   AND C.DATAFECHAMENTO IS NULL;
				   
# 				RETURN OLD;
# 			END IF;
# 		END IF;
		
# 	ELSIF TG_OP = 'INSERT' THEN
# 		IF NEW.COD_TPHITORICO = 16 THEN
# 			RETURN NEW;
# 		END IF;

# 		IF NEW.COD_BANCOCONTA IS NULL THEN
# 			IF NEW.TIPO = 'E' THEN
# 				SELECT C.VALORENTRADAS INTO VLCAIXA 
# 				  FROM CAIXA AS C
# 				 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND DATAFECHAMENTO IS NULL;
				
# 				UPDATE CAIXA AS C
# 				   SET VALORENTRADAS = (VLCAIXA + NEW.VALOR)
# 				 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND DATAFECHAMENTO IS NULL;
# 				   RETURN NEW;
# 			ELSIF NEW.TIPO = 'S' THEN
# 				SELECT C.VALORSAIDAS INTO VLCAIXA 
# 				  FROM CAIXA AS C 
# 				 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA
# 				   AND C.DATAFECHAMENTO IS NULL;
				   
# 				UPDATE CAIXA AS C
# 				   SET VALORSAIDAS = (VLCAIXA + NEW.VALOR)
# 				 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND C.DATAFECHAMENTO IS NULL;
# 				   RETURN NEW;
# 			END IF;
			
# 		ELSIF NEW.COD_BANCOCONTA IS NOT NULL THEN
		
# 		--select * from bancoconta where cod_bancoconta = ( select cod_bancoconta from empresa where cod_empresa = 2)
# 			IF NEW.TIPO = 'E' THEN
# 			        -- LANCAMENTO DIVERSO SE ENTRADA NA CONTA SAI DO CAIXA PARA ENTRAR NA CONTA
# 				SELECT B.ENTRADAS INTO VLBANCO 
# 				  FROM BANCOCONTA AS B
# 				 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );
				
# 				UPDATE BANCOCONTA AS B
# 				   SET ENTRADAS = ( VLBANCO + NEW.VALOR )
# 				 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

# 				IF NEW.COD_CONTASPAGREC IS NULL THEN
				
# 					-- ENTRA NA CONTA E SAI DO CAIXA
# 					SELECT C.VALORSAIDAS INTO VLCAIXA 
# 					  FROM CAIXA AS C 
# 					 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA
# 					   AND C.DATAFECHAMENTO IS NULL;
					   
# 					UPDATE CAIXA AS C
# 					   SET VALORSAIDAS = (VLCAIXA + NEW.VALOR)
# 					 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 					   AND C.DATAFECHAMENTO IS NULL; 
# 				END IF;
# 				RETURN NEW;	
				   
# 			ELSIF NEW.TIPO = 'S' THEN
# 				SELECT B.SAIDAS INTO VLBANCO 
# 				  FROM BANCOCONTA AS B
# 				 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );
				
# 				UPDATE BANCOCONTA AS B
# 				   SET SAIDAS = ( VLBANCO + NEW.VALOR)
# 				 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

# 				-- SE FOR UMA SAIDA DA CONTA ENTRA NO CAIXA APENAS SE NAO FOR DE UMA CONTA
# 				IF NEW.COD_CONTASPAGREC IS NULL THEN					
# 					-- SAI DA CONTA E ENTRA NO CAIXA
# 					SELECT C.VALORENTRADAS INTO VLCAIXA 
# 					  FROM CAIXA AS C
# 					 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 					   AND C.DATAFECHAMENTO IS NULL;
					
# 					/*UPDATE CAIXA AS C
# 					   SET VALORENTRADAS = (VLCAIXA + NEW.VALOR)
# 					 WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
# 					   AND C.DATAFECHAMENTO IS NULL;*/
# 				END IF;
# 				RETURN NEW;
				   
				
# 			END IF;
# 		END IF;
		
# 	ELSIF TG_OP = 'UPDATE' THEN

# 		IF OLD.COD_BANCOCONTA IS NOT NULL THEN
			

# --select * from bancoconta where cod_bancoconta = ( select cod_bancoconta from empresa where cod_empresa = 2)
# 			IF NEW.TIPO = 'E' THEN
# 			        -- LANCAMENTO DIVERSO SE ENTRADA NA CONTA SAI DO CAIXA PARA ENTRAR NA CONTA

# 			        IF NEW.COD_BANCOCONTA != OLD.COD_BANCOCONTA THEN
# 					-- SELECIONA PRIMEIRO O REGISTRO A ATUALIZAR PARA ALTERAR OS VALORES

# 					SELECT B.ENTRADAS INTO VLBANCO 
# 					  FROM BANCOCONTA AS B	
# 					 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 					   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;
					
# 					UPDATE BANCOCONTA AS B
# 					   SET ENTRADAS = ( VLBANCO - OLD.VALOR )
# 					 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 					   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

# 					VLBANCO = 0;
# 					SELECT B.ENTRADAS INTO VLBANCO 
# 					  FROM BANCOCONTA AS B	
# 					 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 					   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;
					
# 					UPDATE BANCOCONTA AS B
# 					   SET ENTRADAS = ( VLBANCO + NEW.VALOR )
# 					 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 					   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;
				   
# 			        END IF;
# 				RETURN NEW;	
				   
# 			ELSIF NEW.TIPO = 'S' THEN

# 				SELECT B.SAIDAS INTO VLBANCO 
# 				  FROM BANCOCONTA AS B	
# 				 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;
				
# 				UPDATE BANCOCONTA AS B
# 				   SET SAIDAS = ( VLBANCO - OLD.VALOR )
# 				 WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

# 				VLBANCO = 0;
# 				SELECT B.SAIDAS INTO VLBANCO 
# 				  FROM BANCOCONTA AS B	
# 				 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;
				
# 				UPDATE BANCOCONTA AS B
# 				   SET SAIDAS = ( VLBANCO + NEW.VALOR )
# 				 WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
# 				   AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;

# 				RETURN NEW;
				
# 			END IF;

# 		END IF;

# 		RETURN NULL;
# 	END IF;

	
# RETURN NULL;
# END
# $BODY$;

# ALTER FUNCTION public.tgrf_updatecaixa()
#     OWNER TO jonas;
