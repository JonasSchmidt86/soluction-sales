# Notas Avulsas / Editor de NF

Tela de emissão de nota fiscal **fora do fluxo automático da venda**: emissão
avulsa (sem venda), rascunho editável, e geração de NF **a partir de uma venda**
(para conferir e ajustar antes de transmitir). Emite NF-e (modelo **55**) e
NFC-e (modelo **65**) pelo provedor Brasil NFe.

- Menu: **Fiscal > Notas Avulsas**.
- Rota base: `/collaborators_backoffice/notas_avulsas`.
- Controller: `CollaboratorsBackoffice::NotasAvulsasController`.
- Acesso: `super_admin` em empresa com módulo fiscal ativo.

## Modelos

- **55 (NF-e):** exige destinatário (`cod_pessoa`).
- **65 (NFC-e):** destinatário opcional (consumidor não identificado). O DANFCE
  é devolvido em **HTML**; o DANFE da 55 em **PDF**. A tela detecta o tipo pelos
  primeiros bytes do arquivo e serve com o `Content-Type` correto.

## Estados do documento

O editor trabalha com documentos **em elaboração**: `rascunho` (nunca
transmitido) e `erro` (falha de validação local antes de transmitir — o usuário
corrige e reemite sem perder o documento). Documentos `enviada`, `autorizada` e
`cancelada` já têm andamento/valor fiscal e **não** são editáveis pelo editor.

Exclusão (`destroy`): só remove documentos **não autorizados** (erro, rejeitada,
rascunho, enviada). Nota `autorizada`/`cancelada` tem valor fiscal e deve ser
**cancelada na SEFAZ**, não excluída.

## Fluxos

### 1. Emissão avulsa direta
`new` (seletor 55/65) → preenche itens e destinatário → `create` emite na hora.
Em erro de validação, o formulário é **reexibido preenchido** (sem redirect,
para não perder o que foi digitado).

### 2. Rascunho editável
`salvar_rascunho` cria o `DocumentoFiscal` com status `rascunho` (sem SEFAZ) e
grava os itens em `documento_fiscal_item`. Depois: `edit` reabre o form
preenchido, `update` regrava, `emitir` transmite. O cabeçalho do rascunho guarda
`cod_pessoa_rascunho` e `cod_operacao_fiscal_rascunho`
(migration `20260927000004_add_rascunho_fields_to_documento_fiscal`).

"Salvar e emitir" num clique: o `update` com `emitir_apos` grava e segue direto
para a emissão.

### 3. NF a partir de uma venda
`gerar_de_venda?cod_venda=` (botão na tela de vendas,
`report/rep_sales/_fiscal_acoes`):

- Se a venda já tem NF autorizada → abre a NF existente (não duplica).
- Se já existe rascunho desta venda → **reabre** o rascunho salvo (preserva as
  edições; não sobrescreve).
- Senão, cria um rascunho novo (modelo 55) copiando itens e destinatário da
  venda, com `cod_venda` preenchido (NF de venda, não avulsa), e abre o editor.

A lista (`index`) mostra **todas** as notas da empresa (avulsas, de venda e de
devolução); a coluna "Origem" distingue (usa `cod_vendaempresa` quando há venda).

## Validação de emissão

O backend é a **fonte única de verdade** (`validar_detalhado`). O endpoint
`POST .../validar` recebe o estado do formulário e devolve, em JSON, a lista de
pendências e os **marcadores de campo** para o front pintar de vermelho
(`is-invalid`) e bloquear o botão Emitir. As mesmas checagens rodam de novo no
backend antes de transmitir (`emitir`/`create`), então o JS não é a única trava.

Pendências verificadas:

- **Por item:** cor selecionada, quantidade > 0, valor unitário > 0, CFOP
  resolvido (perfil + operação + regra).
- **Destinatário:** CPF/CNPJ válido quando informado; NF-e 55 exige destinatário.
- **Estoque fiscal consolidado:** soma as quantidades do mesmo produto na nota e
  compara com `fiscal_produto.qtd_fiscal` (saldo fiscal por produto). Estoque
  insuficiente vira pendência e marca as linhas envolvidas.
- **Pagamentos:** se houver pagamentos lançados, a soma deve bater com o total.
- **Duplicatas:** se houver parcelas, a soma deve bater com o total.
- **Transporte:** se informou transportadora/volumes mas a modalidade está
  "9 - Sem transporte", exige escolher a modalidade (0-4) ou remover os dados.

NCM/CSOSN **não** entram aqui — o `EmissorFiscal` cuida e lança
`DadosFiscaisIncompletos` se faltar.

## Cabeçalho fiscal (pagamento, observações, NF referenciada)

Além dos itens e do destinatário, o editor tem abas **Produtos / Pagamento /
Transporte** e grava no cabeçalho da nota (colunas em `documento_fiscal`,
migrations `20260928000001/02/03`; tudo persiste no rascunho):

- **Pagamentos** (`pagamentos`, jsonb → bloco `pag`/tPag): lista de formas
  (forma + valor), como no painel Brasil NFe. **Default: "99 - Outros"** (1
  pagamento = total da nota, com `Descricao` "Outros"). Com o default, a nota
  **não mostra duplicatas ao cliente**. A soma dos pagamentos lançados deve
  bater com o total (validado no painel).
- **Duplicatas / Cobrança** (`cobranca`, jsonb → bloco `cobr`): parcelas com
  vencimento (gerador estilo venda: nº de parcelas + 1º vencimento + intervalo →
  divisão igual, resto na última, datas a cada N dias). **É o que imprime as
  parcelas no DANFE.** Só é enviada quando há parcelas **e** a forma de pagamento
  é a prazo (≠ 99 e ≠ 90); nesse caso o `pag` vai com `IndicadorPagamento=1`.
  Número da fatura: `cod_vendaempresa`; parcelas `cod_vendaempresa-1..n`.
  Ao gerar a NF de uma venda, as parcelas são pré-carregadas de `venda.contas`,
  mas **só vão ao cliente se a forma na NF for a prazo** — no default (99) ficam
  salvas e não são enviadas.
- **Transporte** (`transporte`, jsonb → bloco `transp`): modalidade do frete +
  transportadora (busca de Pessoa) + veículo + volumes. Ver seção Transporte.
- **Informações complementares** (`info_adicional` → Observacao/infCpl): aparece
  no DANFE. **Observações ao fisco** (`info_adicional_fisco` → ObservacaoFisco).
- **NF referenciada** (`chave_referenciada` → NFReferencia): chave de 44 dígitos
  de uma NF-e de compra, para devolução/outra saída. Entrada manual.

O caminho é: form → controller (`cabecalho_param`) → `DocumentoAvulso` →
`DocumentoFiscalBuilder#montar` → `BrasilNfeAdapter#montar_payload`. Uma Venda
comum não responde a esses campos (lidos via `try`), então o fluxo de NF de
venda não muda.

## CFOP automático por item

`resolver_cfop` resolve o CFOP de cada item pela regra do perfil + operação do
topo, com destino = UF do destinatário (ou UF da empresa). Usa
`FiscalProduto.para` (fonte única, com fallback no produto global). "Aprende" o
perfil: se o produto ainda não tem perfil na `fiscal_produto` e o usuário
escolheu um na tela, grava esse perfil na `fiscal_produto` da empresa (só quando
está vazio).

## Pré-visualização

`POST .../previsualizar` gera o DANFE/DANFCE **sem transmitir à SEFAZ** a partir
dos itens/destinatário do formulário, para conferência visual antes de emitir.

## Rotas

| Método | Rota | Ação |
|---|---|---|
| GET | `notas_avulsas` | index (lista) |
| GET | `notas_avulsas/new` | form de emissão (55/65) |
| POST | `notas_avulsas` | create (emite direto) |
| GET | `notas_avulsas/:id` | show (detalhe; lê itens do XML) |
| GET | `notas_avulsas/:id/edit` | edita rascunho |
| PATCH/PUT | `notas_avulsas/:id` | update (regrava rascunho) |
| DELETE | `notas_avulsas/:id` | exclui não autorizada |
| GET | `notas_avulsas/:id/danfe` | DANFE/DANFCE (autorizada) |
| POST | `notas_avulsas/:id/cancelar` | cancela autorizada |
| POST | `notas_avulsas/:id/emitir` | emite rascunho salvo |
| GET | `notas_avulsas/cores_produto` | cores do produto (select) |
| POST | `notas_avulsas/previsualizar` | DANFE/DANFCE de pré-visualização |
| GET | `notas_avulsas/resolver_cfop` | resolve CFOP de um item |
| POST | `notas_avulsas/salvar_rascunho` | salva rascunho editável |
| POST | `notas_avulsas/gerar_de_venda` | cria/reabre rascunho de uma venda |
| POST | `notas_avulsas/validar` | valida o form e devolve pendências (JSON) |

## Efeito no estoque fiscal

Emitir/cancelar NF mexe **só no estoque fiscal** (`qtdfiscal` por cor +
`fiscal_produto.qtd_fiscal` consolidado), via `Fiscal::EstoqueFiscalService`;
**não** toca o estoque físico. Ver
[FISCAL_PRODUTO.md](FISCAL_PRODUTO.md#log-de-estoque-fiscal-estoque_logs).
