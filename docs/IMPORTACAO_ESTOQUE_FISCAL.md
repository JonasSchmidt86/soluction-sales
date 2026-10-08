# Importação de Estoque Fiscal

## Objetivo

A tela importa uma planilha de inventário para revisar dados fiscais dos produtos e definir o saldo fiscal por empresa/produto/cor. A quantidade da planilha é tratada como **saldo contado**: ao salvar, substitui `empresaproduto.qtdfiscal` da cor escolhida. O estoque físico (`empresaproduto.quantidade`) não é alterado.

## Acesso

- Menu: **Fiscal > Importar Estoque**.
- Rota: `/collaborators_backoffice/importacao_estoque_fiscal`.
- Acesso permitido a `super_admin` em empresa com módulo fiscal ativo.

## Planilha

São aceitos arquivos `.csv`, `.xlsx` e `.xlsm`, com limite de 20 MB. CSV usa `;` ou `,` como separador, detectado pelo cabeçalho. No Excel, é lida a primeira aba.

Cabeçalhos reconhecidos:

| Dado | Cabeçalhos reconhecidos |
|---|---|
| Código | Código Produto, Código do Produto, Cod Produto, Código |
| Nome da planilha | Nome, Nome do Produto, Produto, Descrição |
| NCM da planilha | NCM |
| Unidade | Unidade Medida, Unidade de Medida, Unidade, UCOM |
| Quantidade | Quantidade, QTD, Estoque, Saldo Fiscal |

Código e quantidade são obrigatórios para uma linha válida. A quantidade precisa ser numérica, não negativa e ter no máximo duas casas decimais. NCM e unidade da planilha são informativos na prévia; não atualizam o cadastro automaticamente.

## Origem das Informações

| Coluna da tela | Origem |
|---|---|
| Linha, código, nome da planilha, NCM da planilha, unidade e quantidade | Linha correspondente do CSV/XLSX |
| Nome cadastrado | `produto.nome`, obtido pelo código da planilha |
| NCM do cadastro, origem, CEST e perfil tributário | Registro `produto` encontrado pelo código |
| Opções de perfil | Registros ativos de `PerfilTributario` |
| Opções de cor e saldo fiscal atual | `empresaproduto` da empresa logada para o produto encontrado, com associação a `cores` |
| Estoque físico exibido no histórico | `empresaproduto.quantidade`; não é alterado pela importação |

O código precisa ser numérico e corresponder a `produto.cod_produto`. Produtos não encontrados ficam sem ação de salvamento. Quando o produto tem uma única cor cadastrada na empresa, a tela já a pré-seleciona; havendo mais de uma, a pessoa deve escolher qual cor receberá o saldo (ver a seção Cor da Linha).

## NCM e Dados Fiscais

O NCM da planilha e o NCM atual do cadastro aparecem lado a lado. O botão de alternância escolhe qual NCM será enviado no salvamento; os valores não são editados diretamente nessa tela. Se o cadastro estiver sem NCM, o NCM da planilha é selecionado inicialmente. Se já houver NCM no cadastro, o próprio cadastro é a seleção inicial.

Também podem ser informados o nome cadastrado, o perfil tributário, a origem e o CEST. O nome é obrigatório e limitado a 100 caracteres. NCM deve ter 8 dígitos, CEST 7 dígitos e origem deve ser de `0` a `8`. O perfil selecionado precisa estar ativo.

## Cor da Linha

A cor que recebe o saldo fiscal é obrigatória, pois o estoque é separado por produto e cor. Quando o produto tem **uma única cor** cadastrada na empresa, a tela já pré-seleciona essa cor automaticamente (com o aviso "Cor única pré-selecionada"), dispensando a escolha manual. Quando há mais de uma cor, a pessoa precisa selecionar qual delas receberá o saldo.

## Salvamento em Lote

O botão **Salvar todas as linhas prontas** envia, em uma única requisição, todas as linhas que têm produto encontrado, cor selecionada (incluindo as pré-selecionadas por cor única) e sem erros de validação. Antes de enviar, a tela confirma quantas linhas serão salvas e quantas ficarão de fora por não terem cor escolhida.

No servidor, cada linha do lote é processada em seu próprio ponto de salvamento (savepoint): uma linha que falhe é revertida isoladamente, sem afetar as demais já gravadas no mesmo envio. O estado temporário (rascunho) é reescrito uma única vez ao final do lote. A resposta traz o total salvo e o resultado por linha, para a tela remover as linhas salvas e exibir o erro das que não passaram.

O salvamento em lote usa exatamente a mesma lógica de gravação do salvamento individual (campos fiscais, saldo fiscal, `ProdutoFiscalLog` e `EstoqueLog`), apenas aplicada a várias linhas de uma vez. É o caminho recomendado para inventários grandes, por reduzir centenas de requisições individuais a um único envio.

## Salvamento por Linha

O botão **Salvar linha** envia somente a linha selecionada. No servidor, a aplicação:

1. Revalida a prévia, o índice original da linha, produto, cor, empresa e campos fiscais.
2. Localiza o produto por `Produto.find(cod_produto)`.
3. Atualiza os campos fiscais preenchidos pelo usuário e registra suas alterações em `ProdutoFiscalLog`.
4. Define `empresaproduto.qtdfiscal` para o saldo informado, na cor selecionada.
5. Registra a diferença do saldo fiscal em `EstoqueLog`, com origem `AJUSTE` e origem do sistema `FISCAL_IMPORT`.
6. Executa as gravações de produto, saldo e logs na mesma transação.
7. Marca a linha como salva no rascunho somente após a transação ser concluída.

Linhas salvas desaparecem da prévia após a resposta de sucesso e continuam ocultas após recarregar a página. O rascunho é associado à empresa e ao colaborador da sessão, expira após 24 horas e pode ser descartado pelo botão da tela. Uma tentativa repetida para uma linha já marcada é recusada.

## Limitações e Cuidados

- A quantidade representa saldo final contado, não entrada incremental.
- A cor é obrigatória porque o estoque é separado por produto e cor.
- A tela não cria vínculos de cor nem cria produtos. A única pré-seleção automática é a cor, e apenas quando o produto tem exatamente uma cor cadastrada na empresa; nenhum produto é associado por aproximação de nome.
- Linhas repetidas para o mesmo produto/cor são processadas individualmente; a última linha salva define o saldo final. No salvamento em lote, a ordem de processamento segue a ordem enviada pela tela.
- Um erro antes do commit reverte produto, saldo e logs daquela linha. Se a transação concluir, mas falhar a gravação do estado temporário, a resposta orienta recarregar para conferir o rascunho.
- A seleção NCM e os campos fiscais são aplicados no cadastro global `produto`; o saldo fiscal é aplicado ao vínculo `empresaproduto` da empresa e cor escolhidas.

## Implementação

- Leitura e validação: `Fiscal::ImportacaoEstoquePlanilha`.
- Upload, prévia temporária, resolução de produto/cor (incluindo a pré-seleção de cor única) e salvamento: `CollaboratorsBackoffice::ImportacaoEstoqueFiscalController`.
  - `salvar_linha`: grava uma linha (ação individual).
  - `salvar_lote`: grava várias linhas em um envio; cada linha em seu savepoint.
  - `processar_linha!`: lógica de gravação compartilhada pelas duas ações (campos fiscais, saldo fiscal, `ProdutoFiscalLog` e `EstoqueLog`), executada dentro de uma transação aberta pelo chamador.
- Rotas: `salvar_linha_importacao_estoque_fiscal` (individual) e `salvar_lote_importacao_estoque_fiscal` (lote).
- Apresentação e ações (individual e em lote): `app/views/collaborators_backoffice/importacao_estoque_fiscal/index.html.erb`.