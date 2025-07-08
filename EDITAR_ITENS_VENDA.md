# Funcionalidade: Editar Itens de Venda

## Descrição
Esta funcionalidade permite editar itens de uma venda já cadastrada, especificamente para trocar a cor do produto e ajustar o valor unitário, sem precisar refazer toda a venda.

## Como usar

### 1. Acessar a edição de itens
- Vá para o relatório de vendas (Relatório Vendas)
- Localize a venda que deseja editar
- Clique no menu de ações (três pontos) da venda
- Selecione "Editar Itens"

### 2. Editar os itens
- Na tela de edição, você verá todos os itens da venda
- Para cada item, você pode:
  - **Trocar a cor**: Selecione uma nova cor no dropdown "Nova Cor"
  - **Ajustar o valor**: Modifique o valor unitário no campo "Valor Unit."
- O valor total de cada linha é atualizado automaticamente
- Quando você troca a cor, o sistema busca automaticamente o valor padrão da nova cor

### 3. Salvar as alterações
- Clique em "Salvar Alterações" para confirmar as mudanças
- O valor total da venda será recalculado automaticamente
- Você será redirecionado para o relatório de vendas com uma mensagem de sucesso

## Permissões
- Apenas usuários com nível de permissão 1 (administradores) podem editar itens de venda
- Vendas canceladas não podem ser editadas

## Funcionalidades técnicas
- **Validação de permissões**: Verifica se o usuário tem autorização
- **Validação de status**: Impede edição de vendas canceladas
- **Atualização automática de valores**: Recalcula totais quando cores ou valores são alterados
- **Interface responsiva**: Funciona bem em diferentes tamanhos de tela
- **Feedback visual**: Hover effects e indicadores visuais para melhor experiência

## Arquivos modificados/criados
- `config/routes.rb` - Novas rotas para edição de itens
- `app/controllers/collaborators_backoffice/vendas_controller.rb` - Métodos para editar e atualizar itens
- `app/views/collaborators_backoffice/vendas/editar_itens.html.erb` - Interface de edição
- `app/views/collaborators_backoffice/report/rep_sales/index.html.erb` - Link para edição
- `app/assets/stylesheets/editar_itens.css` - Estilos específicos

## Benefícios
- **Economia de tempo**: Não precisa refazer toda a venda para trocar uma cor
- **Flexibilidade**: Permite ajustes rápidos em vendas já cadastradas
- **Controle**: Mantém histórico e integridade dos dados
- **Usabilidade**: Interface intuitiva e fácil de usar