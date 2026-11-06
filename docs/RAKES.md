# Rake tasks do projeto

Índice das rake tasks **customizadas** (criadas para este ERP, em `lib/tasks/`).
Não inclui as tasks nativas do Rails (`db:migrate`, `assets:precompile`, etc.).

Para listar as tasks com descrição direto no terminal:

```bash
bundle exec rails -T            # todas
bundle exec rails -T fiscal     # só o namespace fiscal
```

## Convenções

A maioria das tasks de correção/migração de dados segue o mesmo padrão de segurança:

- **DRY-RUN por padrão**: a task roda sem gravar nada, só mostra o que mudaria.
  Para aplicar de verdade é preciso `APPLY=1` (ou `DRY_RUN` nas que usam o inverso).
- **`EMPRESA=n`**: filtra por uma empresa (algumas exigem, outras é opcional).
- **Idempotente**: pode rodar várias vezes sem duplicar/estragar nada.
- Ajustes de estoque fiscal gravam histórico em `estoque_logs`.

> Sempre rode primeiro em DRY-RUN, confira a prévia, e só então use `APPLY=1`.

---

## Resumo

| Task | Namespace | O que faz | Grava? |
|---|---|---|---|
| `fiscal:backfill_fiscal_produto` | fiscal | Cria `fiscal_produto` por (empresa, produto) a partir do produto global | `APPLY=1` |
| `fiscal:ratear_qtdfiscal` | fiscal | Rateia `fiscal_produto.qtd_fiscal` entre as cores de `empresaproduto` | `APPLY=1` |
| `produtos:atualizar_origem_nfe` | produtos | Atualiza dados fiscais do produto (origem/NCM/CEST/GTIN/UCOM) a partir das NF-e de compra | `APPLY=1` |
| `notas_recebidas:backfill_natureza` | notas_recebidas | Preenche `natureza_operacao` nas notas recebidas (lê/baixa XML) | sempre (idempotente) |
| `notas_recebidas:vincular_compras` | notas_recebidas | Sincroniza o vínculo nota recebida × compra | `DRY_RUN=1` só mostra |
| `xml_files:backfill_numeronf` | xml_files | Preenche `numeronf` e `chave` dos `xml_files` (lê o XML) | sempre (só o vazio) |
| `cidade:corrige_homonima` | cidade | Corrige pessoas numa cidade homônima de UF errada | `APPLY=1` |
| `dev:setup` (+ `dev:*`) | dev | Prepara o ambiente de desenvolvimento / dados padrão | sim (dev) |

---

## Detalhes

### `fiscal:backfill_fiscal_produto`

Arquivo: `lib/tasks/backfill_fiscal_produto.rake` · doc: `docs/FISCAL_PRODUTO.md`

Cria **uma** linha em `fiscal_produto` por par (`cod_empresa`, `cod_produto`) que
existe em `empresaproduto` e ainda não tem registro fiscal. Copia os dados
fiscais do cadastro **global** do produto (NCM, CFOP, CEST, origem, GTIN, CSOSN,
`cod_perfil_tributario`). O `qtd_fiscal` nasce **0** (é populado depois pela
importação de inventário ou pelo uso do sistema).

- NCM/CEST/GTIN/origem/CSOSN são higienizados; valor inválido vira `NULL`
  (o produto fica como pendência fiscal até ser corrigido, em vez de gravar errado).
- Idempotente (`ON CONFLICT (cod_empresa, cod_produto) DO NOTHING`).

```bash
bundle exec rails fiscal:backfill_fiscal_produto              # DRY-RUN, todas
EMPRESA=2 bundle exec rails fiscal:backfill_fiscal_produto    # DRY-RUN, empresa 2
APPLY=1 EMPRESA=2 bundle exec rails fiscal:backfill_fiscal_produto   # grava, empresa 2
APPLY=1 bundle exec rails fiscal:backfill_fiscal_produto      # grava, todas
```

Parâmetros: `APPLY=1` grava · `EMPRESA=n` filtra (opcional).

---

### `fiscal:ratear_qtdfiscal`

Arquivo: `lib/tasks/ratear_qtdfiscal.rake` · doc: `docs/FISCAL_PRODUTO.md#rake-fiscalratear_qtdfiscal`

Trata `fiscal_produto.qtd_fiscal` (consolidado por produto) como **fonte da
verdade** e reescreve `empresaproduto.qtdfiscal` (por cor) para que a **soma por
produto** bata com o consolidado. A distribuição entre as cores é proporcional
ao **estoque físico** (`empresaproduto.quantidade`).

Use para **equiparar o estoque fiscal das cores ao `fiscal_produto.qtd_fiscal`**
(ex.: quando o `qtdfiscal` por cor ficou inflado por entradas de compra sem as
saídas correspondentes).

- `fiscal_produto.qtd_fiscal` **não** é alterado.
- Rateio em números inteiros; a sobra de arredondamento vai para a cor de maior
  estoque físico.
- Produto com físico 0 em todas as cores: joga tudo na **cor 1** (ou na única cor).
- **Não** altera `empresaproduto.quantidade` (estoque físico).
- Só processa produtos com `qtd_fiscal > 0`.
- Loga cada ajuste em `estoque_logs` (operação `RATEIO_FISC`, origem
  `EMPRESA_PRODUTO`, `origem_sistema=RAKE`).

```bash
EMPRESA=2 bundle exec rails fiscal:ratear_qtdfiscal           # DRY-RUN
APPLY=1 EMPRESA=2 bundle exec rails fiscal:ratear_qtdfiscal   # grava
```

Parâmetros: `EMPRESA=n` **obrigatório** · `APPLY=1` grava.

---

### `produtos:atualizar_origem_nfe`

Arquivo: `lib/tasks/produtos_origem_nfe.rake` · serviço: `Fiscal::OrigemProdutoNfeService`

Audita e atualiza os campos fiscais do cadastro de produto (origem, NCM, CEST,
GTIN, UCOM) usando como fonte a **NF-e de compra mais recente** de cada produto.
Gera um relatório detalhado no terminal e um **CSV de auditoria** em `tmp/`
(classifica cada campo: já correto, a atualizar, divergência, conflito histórico,
vínculo ambíguo, sem fonte). O CFOP é apenas informativo (não altera).

```bash
bundle exec rails produtos:atualizar_origem_nfe              # DRY-RUN + relatório + CSV
APPLY=1 bundle exec rails produtos:atualizar_origem_nfe      # grava
REPORT_PATH=/caminho/x.csv bundle exec rails produtos:atualizar_origem_nfe
```

Parâmetros: `APPLY=1` grava · `REPORT_PATH=` caminho do CSV (opcional; default `tmp/`).

---

### `notas_recebidas:backfill_natureza`

Arquivo: `lib/tasks/backfill_natureza_notas_recebidas.rake` · serviço: `Fiscal::NotasRecebidasService`

Preenche `natureza_operacao` (natOp) nas notas recebidas gravadas sem esse campo.
A natureza só existe no XML; notas registradas via "Ver entradas na SEFAZ" /
"Salvar por chave" ficaram sem. Para cada nota: lê do XML já anexado ou, se não
houver, **baixa o XML da SEFAZ** (a menos que `SEM_SEFAZ=1`), anexa e extrai.
Idempotente.

```bash
bundle exec rails notas_recebidas:backfill_natureza            # todas as empresas
EMPRESA=2 bundle exec rails notas_recebidas:backfill_natureza  # só empresa 2
SEM_SEFAZ=1 bundle exec rails notas_recebidas:backfill_natureza # só o que tem XML local
```

Parâmetros: `EMPRESA=n` filtra (opcional) · `SEM_SEFAZ=1` não baixa da SEFAZ.

---

### `notas_recebidas:vincular_compras`

Arquivo: `lib/tasks/vincular_compras_notas_recebidas.rake`

Mantém `nota_recebida.cod_compra` coerente com as compras reais (correção do que
ficou para trás antes do `Compra`/`ComprasController#destroy` passarem a cuidar
disso). Idempotente.

- **Solta**: nota ligada a compra cancelada/inexistente volta a `cod_compra = NULL`
  (reaparece o botão Importar). Também solta XML preso a compra cancelada.
- **Liga**: nota cujo XML (`xml_file.compra_id`) já aponta para uma compra não
  cancelada e está sem compra → liga a ela (critério exato pelo XML, sem adivinhar
  por número de NF).

```bash
bundle exec rails notas_recebidas:vincular_compras             # todas, grava
EMPRESA=2 bundle exec rails notas_recebidas:vincular_compras   # só empresa 2
DRY_RUN=1 bundle exec rails notas_recebidas:vincular_compras   # só mostra, não grava
```

Parâmetros: `EMPRESA=n` filtra (opcional) · `DRY_RUN=1` só mostra.

---

### `xml_files:backfill_numeronf`

Arquivo: `lib/tasks/backfill_xml_files.rake`

Preenche `numeronf` (nNF) e `chave` (44 dígitos) dos `xml_files` existentes,
lendo cada XML anexado. Só grava o que estiver **vazio** (não sobrescreve).
Idempotente.

```bash
bundle exec rails xml_files:backfill_numeronf              # todos
EMPRESA=2 bundle exec rails xml_files:backfill_numeronf    # só empresa 2
```

Parâmetros: `EMPRESA=n` filtra (opcional).

---

### `cidade:corrige_homonima`

Arquivo: `lib/tasks/corrige_cidade_homonima.rake`

Corrige pessoas vinculadas a uma cidade **homônima de UF errada** (ex.: Toledo/MG
no lugar de Toledo/PR), causada por cadastro por CEP que casava a cidade só pelo
nome (bug já corrigido na view). Reatribui o `cod_cidade` correto. Idempotente.

- Segurança: só migra quem **não** tem CEP claramente de outra UF (mantém e lista
  à parte os que têm CEP de outra faixa, para conferência manual).

```bash
bundle exec rails cidade:corrige_homonima                  # DRY-RUN (default Toledo MG->PR)
APPLY=1 bundle exec rails cidade:corrige_homonima          # grava
DE=5294 PARA=43 APPLY=1 bundle exec rails cidade:corrige_homonima
```

Parâmetros: `APPLY=1` grava · `DE=` cod_cidade errado (default 5294) · `PARA=`
cod_cidade correto (default 43).

---

### `dev:setup` e tasks `dev:*`

Arquivo: `lib/tasks/dev.rake`

Tasks de **ambiente de desenvolvimento** (não usar em produção para dados reais):

- `dev:setup` — roda `db:migrate` e cria o colaborador padrão (`admin@admin.com` /
  senha `123456`, `cod_funcionario: 1`, `cod_empresa: 2`).
- `dev:add_default_collaborator` — cria só o colaborador padrão.
- `dev:add_default_user` — cria o usuário padrão (`user@user.com`).
- `dev:add_default_cidade` / `add_default_empresa` / `add_default_pessoa` /
  `add_default_funcionario` — seeds individuais (a maioria comentada no `setup`).

```bash
bundle exec rails dev:setup
```

---

## Scripts (não são rake)

Em `lib/tasks/` há também dois scripts Ruby (não são rake tasks — não têm
`namespace`/`task`; rode com `rails runner`). Ambos geram um arquivo `.sql` em
`backup/`:

- **`backup_geral.rb`** — dump de tabelas selecionadas via `pg_dump`
  (`active_storage_*`, `custom_reports`, `produto_imagens`, `whatsapp_contacts`,
  `collaborators`) + UPDATEs de `titulo`/`descricao` dos produtos. Gera
  `backup/backup_geral_<timestamp>.sql`. As credenciais do banco (`USER_DB`,
  `DB_NAME`) estão fixas no topo do arquivo — confira antes de rodar em outra máquina.
- **`backup_produtos_empresa.rb`** — gera UPDATEs de `titulo`/`descricao` dos
  produtos (subconjunto do `backup_geral.rb`).

```bash
bundle exec rails runner lib/tasks/backup_geral.rb
```

Consulte o cabeçalho de cada um antes de usar.
