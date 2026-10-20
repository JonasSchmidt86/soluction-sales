# Backfill da tabela fiscal_produto (Etapa 3 do modulo fiscal por empresa).
#
# Cria UMA linha em fiscal_produto por par (cod_empresa, cod_produto) existente
# em empresaproduto, copiando os dados fiscais do cadastro GLOBAL do produto
# (ncm/cfop/cest/origem/gtin/csosn/cod_perfil_tributario). qtd_fiscal nasce 0
# (sera populada pela importacao do sistema atual).
#
# Idempotente: usa ON CONFLICT (cod_empresa, cod_produto) DO NOTHING, entao
# rodar de novo NAO duplica nem sobrescreve registros ja existentes.
#
# Seguro: por padrao e DRY-RUN (so conta/mostra). So grava com APPLY=1.
#
# Uso:
#   # ver quantos registros seriam criados (nao grava):
#   rails fiscal:backfill_fiscal_produto
#   # so a empresa 2 (recomendado para comecar):
#   EMPRESA=2 rails fiscal:backfill_fiscal_produto
#   # aplicar de verdade (empresa 2):
#   APPLY=1 EMPRESA=2 rails fiscal:backfill_fiscal_produto
#   # aplicar para TODAS as empresas:
#   APPLY=1 rails fiscal:backfill_fiscal_produto
namespace :fiscal do
  desc "Backfill fiscal_produto a partir do produto global (DRY-RUN; APPLY=1 grava; EMPRESA=n filtra)"
  task backfill_fiscal_produto: :environment do
    apply   = ENV["APPLY"] == "1"
    empresa = ENV["EMPRESA"].presence&.to_i

    filtro_empresa = empresa ? "AND ep.cod_empresa = #{empresa.to_i}" : ""

    # Pares (empresa, produto) distintos que AINDA NAO tem fiscal_produto.
    sql_pendentes = <<~SQL
      SELECT COUNT(*) FROM (
        SELECT DISTINCT ep.cod_empresa, ep.cod_produto
        FROM empresaproduto ep
        JOIN produto p ON p.cod_produto = ep.cod_produto
        LEFT JOIN fiscal_produto fp
          ON fp.cod_empresa = ep.cod_empresa AND fp.cod_produto = ep.cod_produto
        WHERE fp.cod_fiscal_produto IS NULL
          #{filtro_empresa}
      ) t
    SQL

    pendentes = ActiveRecord::Base.connection.select_value(sql_pendentes).to_i
    ja_existentes = FiscalProduto.where(empresa ? { cod_empresa: empresa } : {}).count

    puts "=" * 70
    puts "Backfill fiscal_produto  |  empresa=#{empresa || 'TODAS'}  |  modo=#{apply ? 'APPLY (grava)' : 'DRY-RUN'}"
    puts "  Registros fiscal_produto ja existentes: #{ja_existentes}"
    puts "  Pares (empresa,produto) pendentes de criar: #{pendentes}"
    puts "=" * 70

    unless apply
      puts "DRY-RUN: nada foi gravado. Rode com APPLY=1 para criar os #{pendentes} registros."
      next
    end

    if pendentes.zero?
      puts "Nada a fazer: todos os pares ja possuem fiscal_produto."
      next
    end

    # INSERT ... SELECT: cria todos de uma vez, copiando o fiscal do produto
    # global. qtd_fiscal = 0. ON CONFLICT torna a operacao idempotente.
    sql_insert = <<~SQL
      INSERT INTO fiscal_produto
        (cod_empresa, cod_produto, ncm, cfop, cest, origem, gtin, csosn,
         cod_perfil_tributario, qtd_fiscal, ativo, created_at, updated_at)
      SELECT DISTINCT
        ep.cod_empresa,
        ep.cod_produto,
        -- NCM: limpa nao-digitos. So grava se sobrar EXATAMENTE 8 digitos
        -- (resolve mascara tipo 6302.22.00 -> 63022200). Qualquer outro caso
        -- (placeholders '0'/'1', NCM com 9-10 digitos) vira NULL de proposito,
        -- para nao gravar NCM adivinhado/errado — o produto fica como pendencia
        -- fiscal ate ser corrigido com o valor certo.
        CASE
          WHEN length(regexp_replace(COALESCE(p.ncm, ''), '[^0-9]', '', 'g')) = 8
          THEN regexp_replace(p.ncm, '[^0-9]', '', 'g')
          ELSE NULL
        END,
        p.cfop,
        -- CEST: so grava se tiver exatamente 7 digitos apos limpar; senao NULL.
        CASE
          WHEN length(regexp_replace(COALESCE(p.cest, ''), '[^0-9]', '', 'g')) = 7
          THEN regexp_replace(p.cest, '[^0-9]', '', 'g')
          ELSE NULL
        END,
        NULLIF(LEFT(TRIM(COALESCE(p.origem, '')), 1), ''),
        NULLIF(LEFT(regexp_replace(COALESCE(p.gtin, ''), '[^0-9]', '', 'g'), 14), ''),
        NULLIF(LEFT(TRIM(COALESCE(p.csosn, '')), 4), ''),
        p.cod_perfil_tributario,
        0,
        TRUE,
        NOW(),
        NOW()
      FROM empresaproduto ep
      JOIN produto p ON p.cod_produto = ep.cod_produto
      LEFT JOIN fiscal_produto fp
        ON fp.cod_empresa = ep.cod_empresa AND fp.cod_produto = ep.cod_produto
      WHERE fp.cod_fiscal_produto IS NULL
        #{filtro_empresa}
      ON CONFLICT (cod_empresa, cod_produto) DO NOTHING
    SQL

    criados = 0
    ActiveRecord::Base.transaction do
      resultado = ActiveRecord::Base.connection.exec_update(sql_insert)
      criados = resultado.to_i
    end

    puts "OK. Registros criados: #{criados}"
    puts "Total fiscal_produto agora: #{FiscalProduto.where(empresa ? { cod_empresa: empresa } : {}).count}"
  end
end
