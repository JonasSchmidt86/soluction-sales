# Dados Fiscais do Produto por Empresa (`fiscal_produto`)

## Objetivo

Os dados fiscais do produto (NCM, CFOP, CEST, origem, GTIN, CSOSN, perfil
tributário) saíram do cadastro **global** do produto (tabela `produto`) e
passaram a ser **por empresa**, na tabela `fiscal_produto`. Motivo: cada empresa
tem seu próprio regime/perfil, então o mesmo produto pode ser tributado de
formas diferentes em cada estabelecimento.

Também passa a existir aqui a `qtd_fiscal`: estoque fiscal **consolidado por
produto** (soma de todas as cores), para controle interno.

Status: em homologação, aplicado à empresa 2. A leitura tem **fallback** no
produto global, então nada quebra onde ainda não há registro em `fiscal_produto`.

## Tabela `fiscal_produto`

| Campo | Observação |
|---|---|
| `cod_fiscal_produto` | PK |
| `cod_empresa`, `cod_produto` | únicos juntos (um registro por empresa+produto) |
| `ncm` | 8 dígitos |
| `cfop` | CFOP de **entrada** (cadastro/referência) |
| `cest` | 7 dígitos |
| `origem` | 0 a 8 |
| `gtin` | EAN/GTIN |
| `csosn` | cadastro/referência |
| `cod_perfil_tributario` | perfil que resolve CSOSN/CFOP na **saída** |
| `qtd_fiscal` | estoque fiscal total do produto (consolida as cores) |
| `ativo` | — |

Migrations: `create_fiscal_produto` e `create_tgrf_qtdfiscal_produto`.

## Regras de negócio

- **Saída (emissão):** o CFOP e o CSOSN vêm **sempre** da regra do perfil
  tributário (por UF destino e tipo de cliente). O `cfop`/`csosn` da
  `fiscal_produto` são dado de cadastro/entrada, informativos.
- **qtd_fiscal:** total por produto. A `empresaproduto.qtdfiscal` (por cor) e
  suas triggers de compra/venda **continuam existindo e intactas** — a
  `qtd_fiscal` é um controle paralelo consolidado.
- **Módulo fiscal:** o fiscal por empresa só é exibido/gravado quando a empresa
  tem `FiscalConfig` ativo (`empresa.modulo_fiscal?`).

## Fonte única de leitura

`FiscalProduto.para(cod_empresa, cod_produto)` devolve o registro da empresa ou,
na ausência, um **Fallback** que lê do produto global com a mesma interface
(`ncm`, `cfop`, `cest`, `origem`, `gtin`, `csosn`, `cod_perfil_tributario`,
`perfil_tributario`, `qtd_fiscal`). Nunca retorna nil.

Consumidores que usam a fonte única (leitura): `DocumentoFiscalBuilder`,
`CfopResolver`, `DocumentoAvulso`/`ItemAvulso`, `NotasAvulsas#resolver_cfop`,
`ProdutoPerfilFiscalController`, `FiscalPendenciasController`, e as views
`vendas/_itensvenda_fields`, `produtos/_partial_form`, `produtos/show`,
`fiscal_pendencias/index`.

## Escrita (quem grava na `fiscal_produto`)

- **Importação de estoque fiscal** (`ImportacaoEstoqueFiscalController`): grava
  ncm/cest/origem/perfil por empresa (o nome continua no produto global).
- **Cadastro/edição de produto** (`ProdutosController#create/#update`): além do
  produto global, faz upsert na `fiscal_produto` da empresa logada.
- **Modal "perfil fiscal" da venda** (`ProdutoPerfilFiscalController#update`).
- **Importação de compra via XML** (`ProdutoxmlsController#atualizar_fiscais_do_produto`):
  grava ncm/cest/origem/gtin na `fiscal_produto` da empresa do XML.
- **Cadastro de produto na compra** (`ComprasController#cadastrar_produto`) e o
  modal "novo produto" da tela de XML.

Em todos: NCM/CEST com máscara são limpos (só dígitos); valores fora do formato
(NCM≠8, CEST≠7) não são gravados.

## Validações de formato

- `FiscalProduto`: NCM 8 dígitos, CEST 7 dígitos, origem 0–8 — **sempre** (dado
  novo nasce correto). Permite em branco.
- `Produto`: mesmas regras, mas **só quando o campo é alterado** — para não
  travar a edição de produtos legados que já estão no banco com valor inválido.

## qtd_fiscal — trigger de compra

Trigger nova e independente `tgr_qtdfiscal_produto` (function
`tgrf_qtdfiscal_produto`) em `itemcompra` (AFTER INSERT/UPDATE/DELETE):

- Mantém `fiscal_produto.qtd_fiscal` (consolidado por produto; ignora a cor).
- Só movimenta quando `numeronf > 0` **e** a empresa tem `FiscalConfig` ativo.
- INSERT soma, DELETE subtrai, UPDATE ajusta pela diferença.
- Cria o registro `fiscal_produto` se não existir.
- **Não** altera a trigger de compra existente nem a `empresaproduto.qtdfiscal`.

Melhoria futura: compras que não devem movimentar estoque fiscal (bonificação,
retorno de assistência) — provavelmente controladas por CFOP da compra.

## Migração de dados (backfill)

Rake task `fiscal:backfill_fiscal_produto` (em `lib/tasks`):

- Cria um `fiscal_produto` por par (empresa, produto) existente em
  `empresaproduto`, copiando os dados fiscais do produto global; `qtd_fiscal = 0`.
- **Idempotente** (`ON CONFLICT DO NOTHING`); **DRY-RUN por padrão**, grava com
  `APPLY=1`; filtra por `EMPRESA=n`.
- NCM/CEST fora do formato viram NULL (não grava dado inválido).

Uso:
```
EMPRESA=2 rails fiscal:backfill_fiscal_produto           # só confere (dry-run)
APPLY=1 EMPRESA=2 rails fiscal:backfill_fiscal_produto   # aplica
```

## Pendências

- **Limpeza (futuro):** remover os campos fiscais do produto global e do
  `params_produto` quando houver certeza de que tudo migrou. Reversível.
- Durante a transição, o cadastro de produto grava os fiscais **nos dois**
  lugares (produto global + fiscal_produto), mantendo o fallback funcionando.
