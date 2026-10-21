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

- **Importação de inventário fiscal** (`ImportacaoInventarioController`): grava
  ncm/origem e `qtd_fiscal` por empresa (o nome continua no produto global).
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

## Rake `fiscal:ratear_qtdfiscal`

Rake task em `lib/tasks/ratear_qtdfiscal.rake`. Reescreve
`empresaproduto.qtdfiscal` (por cor) para que a **soma por produto** bata com
`fiscal_produto.qtd_fiscal`, distribuindo conforme o **estoque físico**
(`quantidade`) de cada cor.

Motivo: a `empresaproduto.qtdfiscal` só crescia (entradas de compra com NF, sem
saídas por este sistema), ficando inflada e divergente do inventário real. O
rateio põe o fiscal por cor em linha com onde o produto realmente está.

Regras:

- `fiscal_produto.qtd_fiscal` é a **fonte da verdade** (não é alterada).
- Rateio em **inteiros**: cada cor recebe `floor(total × físico / soma_físico)`;
  a sobra (para fechar o total exato) vai para a cor de maior físico.
- Físico negativo (estoque furado) conta como 0 no peso (não rouba saldo).
- Produto com físico 0 em todas as cores: tudo na cor 1 (ou na única cor).
- **Não** altera `empresaproduto.quantidade` (estoque físico).
- Loga cada ajuste em `estoque_logs` (operação `RATEIO_FISC`, origem
  `EMPRESA_PRODUTO`, `origem_sistema=RAKE`).
- **DRY-RUN por padrão**, grava com `APPLY=1`; `EMPRESA=n` obrigatório.

Uso:
```
EMPRESA=2 rails fiscal:ratear_qtdfiscal           # só confere (dry-run)
APPLY=1 EMPRESA=2 rails fiscal:ratear_qtdfiscal   # aplica
```

## Log de estoque fiscal (`estoque_logs`)

As movimentações do estoque **fiscal** (`qtdfiscal`) são auditadas na tabela
`estoque_logs`, nas colunas `qtdfiscal_antes/movida/depois` (migration
`20260926000006_add_qtdfiscal_to_estoque_logs`), ao lado das colunas de estoque
físico (`quantidade_*`). Cada linha registra também `cod_funcionario`,
`origem_sistema` (`WEB`/`RAKE`) e `observacao`.

- `origem` = **tabela afetada**: `EMPRESA_PRODUTO` (saldo por cor) ou
  `FISCAL_PRODUTO` (consolidado por produto, `cod_cor` nil).
- `operacao` = o que aconteceu. Principais: `ENTRADA_FISCAL` (compra com NF, na
  trigger `tgrf_qtdfiscal_produto`), `SAIDA_FISCAL`/`ESTORNO_FISCAL`
  (emissão/cancelamento de NF, via `Fiscal::EstoqueFiscalService`), `IMPORT_INV`
  (importação de inventário) e `RATEIO_FISC` (rake de rateio). A coluna
  `operacao` tem limite de 15 caracteres.

> Nomes `EMPRESA_PRODUTO`/`FISCAL_PRODUTO` foram padronizados (antes
> `NFE_FISCAL`/`FISCAL_PROD`) na migration `20260927000005`, que também ajustou
> o histórico existente.

**Quem grava:**

- Trigger `tgrf_qtdfiscal_produto` (entrada de compra com NF) — grava o log
  consolidado e captura quem fez (`app.current_funcionario`, fallback na compra)
  e de onde veio (`app.origem_sistema`, fallback `TRIGGER`).
- `Fiscal::EstoqueFiscalService` (saída na emissão de NF; estorno no
  cancelamento) — só mexe no fiscal, nunca no físico.
- `Fiscal::AplicadorInventario` (importação de inventário).
- `fiscal:ratear_qtdfiscal` (rateio por físico).

## Pendências

- **Limpeza (futuro):** remover os campos fiscais do produto global e do
  `params_produto` quando houver certeza de que tudo migrou. Reversível.
- Durante a transição, o cadastro de produto grava os fiscais **nos dois**
  lugares (produto global + fiscal_produto), mantendo o fallback funcionando.
