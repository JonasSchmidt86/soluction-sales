# Sistema de Orçamentos

## Descrição

Sistema de cadastro de orçamentos que podem ser convertidos em vendas, com controle de estoque integrado.

## Funcionalidades

### 1. Cadastro de Orçamentos
- Criar orçamentos com múltiplos itens
- Vincular cliente e vendedor
- Definir data de validade
- Adicionar observações
- Aplicar descontos e acréscimos

### 2. Gestão de Itens
- Adicionar produtos ao orçamento
- Definir quantidade e valor unitário
- Aplicar descontos/acréscimos por item
- Visualizar estoque disponível em tempo real

### 3. Status do Orçamento
- **Pendente**: Orçamento aguardando aprovação
- **Aprovado**: Orçamento aprovado pelo cliente
- **Rejeitado**: Orçamento recusado
- **Convertido**: Orçamento já convertido em venda

### 4. Conversão em Venda
- Converter orçamentos aprovados em vendas
- Transferência automática de todos os itens
- Manutenção do vínculo entre orçamento e venda
- Controle de estoque automático após conversão

## Como Usar

### Criar um Novo Orçamento

1. Acesse o menu "Orçamentos"
2. Clique em "Novo Orçamento"
3. Selecione o cliente
4. Adicione os itens desejados
5. Defina valores e condições
6. Salve o orçamento

### Converter Orçamento em Venda

1. Abra o orçamento desejado
2. Verifique se há estoque disponível para todos os itens
3. Clique em "Converter em Venda"
4. Confirme a conversão
5. O sistema criará automaticamente a venda e atualizará o estoque

## Instalação

### 1. Executar a Migration

```bash
rails db:migrate
```

### 2. Adicionar ao Menu (opcional)

Edite o arquivo de layout do menu e adicione:

```erb
<li class="nav-item">
  <%= link_to collaborators_backoffice_orcamentos_path, class: 'nav-link' do %>
    <i class="nav-icon fas fa-file-invoice"></i>
    <p>Orçamentos</p>
  <% end %>
</li>
```

## Estrutura do Banco de Dados

### Tabela: orcamentos
- `cod_orcamento` (PK): Código do orçamento
- `cod_empresa`: Empresa
- `cod_pessoa`: Cliente
- `cod_funcionario`: Vendedor
- `data_orcamento`: Data do orçamento
- `data_validade`: Data de validade
- `valortotal`: Valor total
- `desconto`: Desconto aplicado
- `acrescimo`: Acréscimo aplicado
- `status`: Status (pendente/aprovado/rejeitado/convertido)
- `observacoes`: Observações
- `cod_venda`: Venda gerada (quando convertido)

### Tabela: itens_orcamentos
- `cod_item` (PK): Código do item
- `cod_orcamento` (FK): Orçamento
- `cod_produto` (FK): Produto
- `cod_cor` (FK): Cor do produto
- `cod_empresa` (FK): Empresa
- `quantidade`: Quantidade
- `valorunitario`: Valor unitário
- `valor_desconto`: Desconto do item
- `valor_acrescimo`: Acréscimo do item

## Validações

- Cliente, vendedor e empresa são obrigatórios
- Data do orçamento é obrigatória
- Itens devem ter produto, quantidade e valor unitário
- Quantidade deve ser maior que zero
- Orçamentos convertidos não podem ser editados
- Orçamentos rejeitados não podem ser convertidos

## Controle de Estoque

O sistema verifica o estoque disponível:
- Na visualização do orçamento (indicador visual)
- Antes da conversão em venda
- Após a conversão, o estoque é automaticamente atualizado através da venda

## Rotas Disponíveis

```ruby
GET    /collaborators_backoffice/orcamentos          # Listar orçamentos
GET    /collaborators_backoffice/orcamentos/new      # Novo orçamento
POST   /collaborators_backoffice/orcamentos          # Criar orçamento
GET    /collaborators_backoffice/orcamentos/:id      # Visualizar orçamento
GET    /collaborators_backoffice/orcamentos/:id/edit # Editar orçamento
PATCH  /collaborators_backoffice/orcamentos/:id      # Atualizar orçamento
DELETE /collaborators_backoffice/orcamentos/:id      # Excluir orçamento
POST   /collaborators_backoffice/orcamentos/:id/converter_venda # Converter em venda
```

## Dependências

- Rails 7.1+
- PostgreSQL
- Cocoon (para nested forms)
- Kaminari (para paginação)
- Devise (para autenticação)

## Observações

- O sistema utiliza a view `view_estoque_real` para consultar o estoque disponível
- A conversão em venda cria automaticamente os itens de venda e contas a receber (se configurado)
- Orçamentos convertidos mantêm o vínculo com a venda gerada
- O estoque é controlado automaticamente através do modelo Venda existente
