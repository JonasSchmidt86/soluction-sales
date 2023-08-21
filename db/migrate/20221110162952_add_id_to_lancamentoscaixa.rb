class AddIdToLancamentoscaixa < ActiveRecord::Migration[5.2]
  def change
    add_column :lancamentoscaixa, :caixa_id, :bigint;

#    update lancamentoscaixa as l
#       set caixa_id = x.id
#     from caixa as x
#   where l.dataabertura = x.dataabertura
#     and l.cod_empresa = x.cod_empresa;
  
  
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


#   alter table lembretes alter column codigo set default nextval('lembretes_sequence'::regclass);
#   alter table funcionarioempresa alter column cod_funcionarioempresa set default nextval('funcionario_codigo_seq'::regclass);
#   alter table funcionario alter column cod_funcionario set default nextval('funcionario_codigo_seq'::regclass);
#   ALTER TABLE Lancamentoscaixa ALTER COLUMN cod_lancamentocaixa SET DEFAULT nextval('lancamentocaixa_sequence'::regclass);


#   # Alteração necessario para por o codigo do caixa no lugar da dataabertura

#   CREATE OR REPLACE FUNCTION public.tgrf_updatecaixa()
#     RETURNS trigger
#     LANGUAGE 'plpgsql'
#     COST 100
#     VOLATILE NOT LEAKPROOF
# AS $BODY$

#       DECLARE
#         VLCAIXA       NUMERIC(15,2);
#         VLBANCO       NUMERIC(15,2);
#         TIPOVENDA     CHARACTER VARYING(1);
#       BEGIN
#       TIPOVENDA = NULL;
#       IF  TG_OP = 'DELETE' THEN
#       IF OLD.COD_BANCOCONTA IS NULL THEN

#       IF OLD.TIPO = 'E' THEN			
#         SELECT C.VALORENTRADAS INTO VLCAIXA 
#           FROM CAIXA AS C 
#         WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
#           AND C.id = OLD.caixa_id;
        
#         UPDATE CAIXA AS C
#           SET VALORENTRADAS = (VLCAIXA - OLD.VALOR)
#         WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND C.id = OLD.caixa_id;
#           RETURN OLD;

#       ELSIF OLD.TIPO = 'S' THEN
#         SELECT C.VALORSAIDAS into VLCAIXA 
#           FROM CAIXA AS C 
#         WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
#           AND C.id = OLD.caixa_id;
          
#         UPDATE CAIXA AS C
#           SET VALORSAIDAS = (VLCAIXA - OLD.VALOR)
#         WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND C.id = OLD.caixa_id;
#           RETURN OLD;

#       END IF;
#       ELSIF OLD.COD_BANCOCONTA IS NOT NULL THEN
#       IF OLD.TIPO = 'E' THEN
#         SELECT B.ENTRADAS INTO VLBANCO 
#           FROM BANCOCONTA AS B
#         WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );
        
#         UPDATE BANCOCONTA AS B
#           SET ENTRADAS = ( VLBANCO - OLD.VALOR )
#         WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

#           -- sai do caixa e Entra no banco
#           SELECT C.VALORSAIDAS into VLCAIXA 
#           FROM CAIXA AS C 
#         WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
#           AND C.DATAFECHAMENTO IS NULL;
          
#         UPDATE CAIXA AS C
#           SET VALORSAIDAS = (VLCAIXA - OLD.VALOR)
#         WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND C.DATAFECHAMENTO IS NULL;
#           RETURN OLD;

#       --  980,  Q F LG
#       --  860,  Q F LG				   
          
#       ELSIF OLD.TIPO = 'S' THEN
#         SELECT B.SAIDAS INTO VLBANCO 
#           FROM BANCOCONTA AS B
#         WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND b.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );
        
#         UPDATE BANCOCONTA AS B
#           SET SAIDAS = ( VLBANCO - OLD.VALOR)
#         WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = OLD.COD_EMPRESA );

#         -- SAI DA CONTA E VOLTA PRO CAIXA
#         --SELECT C.VALORENTRADAS INTO VLCAIXA 
#         --  FROM CAIXA AS C 
#         -- WHERE C.COD_EMPRESA = OLD.COD_EMPRESA
#         --   AND C.DATAFECHAMENTO IS NULL;
        
#         --UPDATE CAIXA AS C
#         --   SET VALORENTRADAS = (VLCAIXA - OLD.VALOR)
#         -- WHERE C.COD_EMPRESA = OLD.COD_EMPRESA 
#         --   AND C.DATAFECHAMENTO IS NULL;
          
#         RETURN OLD;
#       END IF;
#       END IF;

#       ELSIF TG_OP = 'INSERT' THEN
#       IF NEW.COD_TPHITORICO = 16 THEN
#       RETURN NEW;
#       END IF;

#       IF NEW.COD_BANCOCONTA IS NULL THEN
#       IF NEW.TIPO = 'E' THEN
#         SELECT C.VALORENTRADAS INTO VLCAIXA 
#           FROM CAIXA AS C
#         WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND DATAFECHAMENTO IS NULL;
        
#         UPDATE CAIXA AS C
#           SET VALORENTRADAS = (VLCAIXA + NEW.VALOR)
#         WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND DATAFECHAMENTO IS NULL;
#           RETURN NEW;
#       ELSIF NEW.TIPO = 'S' THEN
#         SELECT C.VALORSAIDAS INTO VLCAIXA 
#           FROM CAIXA AS C 
#         WHERE C.COD_EMPRESA = NEW.COD_EMPRESA
#           AND C.DATAFECHAMENTO IS NULL;
          
#         UPDATE CAIXA AS C
#           SET VALORSAIDAS = (VLCAIXA + NEW.VALOR)
#         WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND C.DATAFECHAMENTO IS NULL;
#           RETURN NEW;
#       END IF;

#       ELSIF NEW.COD_BANCOCONTA IS NOT NULL THEN

#       --select * from bancoconta where cod_bancoconta = ( select cod_bancoconta from empresa where cod_empresa = 2)
#       IF NEW.TIPO = 'E' THEN
#               -- LANCAMENTO DIVERSO SE ENTRADA NA CONTA SAI DO CAIXA PARA ENTRAR NA CONTA
#         SELECT B.ENTRADAS INTO VLBANCO 
#           FROM BANCOCONTA AS B
#         WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );
        
#         UPDATE BANCOCONTA AS B
#           SET ENTRADAS = ( VLBANCO + NEW.VALOR )
#         WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

#         IF NEW.COD_CONTASPAGREC IS NULL THEN
        
#           -- ENTRA NA CONTA E SAI DO CAIXA
#           SELECT C.VALORSAIDAS INTO VLCAIXA 
#             FROM CAIXA AS C 
#           WHERE C.COD_EMPRESA = NEW.COD_EMPRESA
#             AND C.DATAFECHAMENTO IS NULL;
            
#           UPDATE CAIXA AS C
#             SET VALORSAIDAS = (VLCAIXA + NEW.VALOR)
#           WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
#             AND C.DATAFECHAMENTO IS NULL; 
#         END IF;
#         RETURN NEW;	
          
#       ELSIF NEW.TIPO = 'S' THEN
#         SELECT B.SAIDAS INTO VLBANCO 
#           FROM BANCOCONTA AS B
#         WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );
        
#         UPDATE BANCOCONTA AS B
#           SET SAIDAS = ( VLBANCO + NEW.VALOR)
#         WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA; --( SELECT COD_BANCOCONTA FROM EMPRESA WHERE COD_EMPRESA = NEW.COD_EMPRESA );

#         -- SE FOR UMA SAIDA DA CONTA ENTRA NO CAIXA APENAS SE NAO FOR DE UMA CONTA
#         IF NEW.COD_CONTASPAGREC IS NULL THEN					
#           -- SAI DA CONTA E ENTRA NO CAIXA
#           SELECT C.VALORENTRADAS INTO VLCAIXA 
#             FROM CAIXA AS C
#           WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
#             AND C.DATAFECHAMENTO IS NULL;
          
#           /*UPDATE CAIXA AS C
#             SET VALORENTRADAS = (VLCAIXA + NEW.VALOR)
#           WHERE C.COD_EMPRESA = NEW.COD_EMPRESA 
#             AND C.DATAFECHAMENTO IS NULL;*/
#         END IF;
#         RETURN NEW;
          
        
#       END IF;
#       END IF;

#       ELSIF TG_OP = 'UPDATE' THEN

#       IF OLD.COD_BANCOCONTA IS NOT NULL THEN



#       --select * from bancoconta where cod_bancoconta = ( select cod_bancoconta from empresa where cod_empresa = 2)
#       IF NEW.TIPO = 'E' THEN
#               -- LANCAMENTO DIVERSO SE ENTRADA NA CONTA SAI DO CAIXA PARA ENTRAR NA CONTA

#               IF NEW.COD_BANCOCONTA != OLD.COD_BANCOCONTA THEN
#           -- SELECIONA PRIMEIRO O REGISTRO A ATUALIZAR PARA ALTERAR OS VALORES

#           SELECT B.ENTRADAS INTO VLBANCO 
#             FROM BANCOCONTA AS B	
#           WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#             AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;
          
#           UPDATE BANCOCONTA AS B
#             SET ENTRADAS = ( VLBANCO - OLD.VALOR )
#           WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#             AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

#           VLBANCO = 0;
#           SELECT B.ENTRADAS INTO VLBANCO 
#             FROM BANCOCONTA AS B	
#           WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#             AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;
          
#           UPDATE BANCOCONTA AS B
#             SET ENTRADAS = ( VLBANCO + NEW.VALOR )
#           WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#             AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;
          
#               END IF;
#         RETURN NEW;	
          
#       ELSIF NEW.TIPO = 'S' THEN

#         SELECT B.SAIDAS INTO VLBANCO 
#           FROM BANCOCONTA AS B	
#         WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;
        
#         UPDATE BANCOCONTA AS B
#           SET SAIDAS = ( VLBANCO - OLD.VALOR )
#         WHERE B.COD_EMPRESA = OLD.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = OLD.COD_BANCOCONTA;

#         VLBANCO = 0;
#         SELECT B.SAIDAS INTO VLBANCO 
#           FROM BANCOCONTA AS B	
#         WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;
        
#         UPDATE BANCOCONTA AS B
#           SET SAIDAS = ( VLBANCO + NEW.VALOR )
#         WHERE B.COD_EMPRESA = NEW.COD_EMPRESA 
#           AND B.COD_BANCOCONTA = NEW.COD_BANCOCONTA;

#         RETURN NEW;
        
#       END IF;

#       END IF;

#       RETURN NULL;
#       END IF;


#       RETURN NULL;
#       END
# 	  $BODY$;

# ALTER FUNCTION public.tgrf_updatecaixa()
#     OWNER TO moveisrosa;

  end
end
