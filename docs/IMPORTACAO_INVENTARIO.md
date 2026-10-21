# Importação de Inventário Fiscal

Fluxo simplificado para **definir o estoque fiscal** (saldo de inventário) por
produto a partir de uma planilha. Substitui a antiga "Importar Estoque"
(`importacao_estoque_fiscal`, removida): aquele fluxo era por produto/cor e
pedia revisão linha a linha; este é por **produto** (consolidado), classifica
tudo automaticamente e importa os itens prontos em lote.

- Menu: **Fiscal > Importar Inventário**.
- Rota base: `/collaborators_backoffice/importacao_inventario`.
- Acesso: `super_admin` em empresa com módulo fiscal ativo
  (`empresa_tem_modulo_fiscal?`).

## O que o módulo grava

Para cada linha importada (produto já existente ou recém-cadastrado):

- `fiscal_produto.qtd_fiscal` (consolidado por produto) **= quantidade** da planilha.
- `empresaproduto.qtdfiscal` da **cor 1** = mesma quantidade (cria o vínculo se
  não existir, com estoque físico 0).
- **Nunca** altera `empresaproduto.quantidade` (estoque físico real).
- NCM: quando a planilha traz um NCM válido e **diferente** do atual, atualiza
  `fiscal_produto.ncm` (opção B) e registra em `produto_fiscal_logs`.
- `produto.ucom` (unidade): só preenche quando está **vazia** (não sobrescreve).
- `empresaproduto.ultimocusto`: só preenche quando está **0/vazio**.
- `empresaproduto.valorvenda`: só preenche quando está **0/vazio**.
- Origem: ao gravar a `fiscal_produto`, se a origem ainda não existe (nem no
  registro nem no produto global), materializa **"0" (Nacional)** como padrão.

Cada gravação registra um `EstoqueLog` (operação `IMPORT_INV`): uma linha para a
cor 1 (origem `EMPRESA_PRODUTO`) e uma consolidada por produto (origem
`FISCAL_PRODUTO`). Ver [FISCAL_PRODUTO.md](FISCAL_PRODUTO.md#log-de-estoque-fiscal-estoque_logs).

## Formato da planilha

Aceita **CSV** (delimitador `,` ou `;`, detectado automaticamente) e **XLSX**.
O cabeçalho é localizado em qualquer linha; os nomes são normalizados (sem
acento, minúsculo), então vários apelidos funcionam.

| Coluna | Obrigatória | Apelidos aceitos | Observação |
|---|---|---|---|
| Nome | sim | `nome`, `produto`, `descricao` | usado no cadastro de produto novo |
| NCM | sim | `ncm` | limpo para dígitos; se vier, precisa ter 8 |
| Quantidade | sim | `quantidade`, `qtd`, `qtde`, `estoque`, `saldo`, `saldofiscal` | saldo fiscal; decimal pt-BR aceito |
| Código | não | `codigo`, `codproduto`, `codigoproduto` | `cod_produto`; se vazio, gera no cadastro |
| Unidade | não | `unidade`, `ucom`, `un`, `unidademedida` | vira `produto.ucom` (máx. 8) |
| Valor Unitário | não | `valorunitario`, `custo`, `valorcusto`, `precocusto` | custo → `ultimocusto` |
| Valor Venda | não | `valorvenda`, `precovenda` | preço → `valorvenda` |

Colunas extras (Data, CNPJ, etc.) são ignoradas. Linhas totalmente vazias são
puladas.

Validações de linha (parser): código não-numérico, nome vazio, NCM vazio ou com
≠ 8 dígitos, quantidade inválida/negativa/com mais de 2 casas.

## Fluxo na tela

1. **Upload + Analisar** — lê a planilha, classifica cada linha e guarda uma
   prévia (rascunho em `storage/fiscal_inventario_imports/<token>.json`, por
   sessão, válido por 24 h). A tela mostra um **resumo** e só os **pendentes**.
2. **Importar** — aplica os itens selecionados (prontos em lote + divergentes
   confirmados). Cada item roda numa sub-transação (`requires_new`): um erro
   não aborta o lote. Itens aplicados são marcados no rascunho.
3. **Cadastro rápido** — para itens não cadastrados: cria `produto` +
   `empresaproduto` (cor 1) e já aplica o inventário. Código auto (maior
   `cod_produto` + 1) ou informado manualmente (não sobrescreve existente).
4. **Excluir linha** — remove uma linha da prévia (só visual, não grava).
   Útil para descartar itens que não serão importados (ex.: assistência com
   código inválido).
5. **Limpar** — descarta a prévia inteira.

## Classificação (quem vai para onde)

`Fiscal::ClassificadorInventario` compara cada linha com o estado atual do banco
e define o status:

| Status | Significado | Tratamento |
|---|---|---|
| `pronto` | produto existe e NCM confere (ou planilha sem NCM) | importa direto, em lote |
| `ncm_divergente` | produto existe mas o NCM da planilha difere do atual | importa atualizando o NCM; destacado na tela |
| `nao_cadastrado` | código vazio/inexistente (ou com letras) | cadastro rápido editável |
| `erro` | falta dado essencial (nome/NCM/quantidade inválidos) | só permite Excluir |

O NCM "atual" usado na comparação é o da `fiscal_produto` (se houver) com
fallback no produto global. Código não-numérico **não** bloqueia (a pessoa pode
apagá-lo para gerar automático ou digitar um válido); erros de
nome/NCM/quantidade bloqueiam.

## Implementação

- Parser: `app/services/fiscal/importacao_inventario_planilha.rb`
  (`Fiscal::ImportacaoInventarioPlanilha`).
- Classificação: `app/services/fiscal/classificador_inventario.rb`
  (`Fiscal::ClassificadorInventario`) — só analisa, não grava.
- Aplicação: `app/services/fiscal/aplicador_inventario.rb`
  (`Fiscal::AplicadorInventario`) — grava uma linha; não abre transação própria
  (o controller controla por linha).
- Controller: `app/controllers/collaborators_backoffice/importacao_inventario_controller.rb`
  (`index`, `analisar`, `importar`, `cadastrar`, `excluir_linha`, `limpar`).
- View: `app/views/collaborators_backoffice/importacao_inventario/index.html.erb`.

## Ordem recomendada (empresa nova no fiscal)

1. `fiscal:backfill_fiscal_produto` — cria `fiscal_produto` por produto copiando
   NCM/CEST/origem/perfil do produto global (ver [FISCAL_PRODUTO.md](FISCAL_PRODUTO.md#migração-de-dados-backfill)).
2. **Importar Inventário** — define os saldos fiscais a partir da planilha.
3. `fiscal:ratear_qtdfiscal` — distribui o saldo consolidado entre as cores por
   estoque físico (ver [FISCAL_PRODUTO.md](FISCAL_PRODUTO.md#rake-fiscalratear_qtdfiscal)).
