# Editor Visual de Orçamentos — Documentação Técnica Atualizada

## Visão geral

O editor visual foi adicionado ao fluxo de orçamentos do backoffice para permitir que o vendedor monte a proposta em tela, com edição inline, troca de tema, upload de fotos, reordenação de itens e atualização automática de totais sem recarregar a página.

Ele foi construído sobre o módulo existente de orçamentos e mantém compatibilidade com o fluxo tradicional de cadastro e impressão.

---

## Estrutura atual em produção

### `Orcamento`

Principais campos e comportamento relevantes ao editor:

- `titulo`: título livre da proposta
- `tema`: tema ativo do documento (`premium`, `classico`, `executivo`)
- `data_validade`: data de validade da proposta
- `desconto`: valor do desconto aplicado
- `observacoes`: observações gerais da proposta
- `recalcular_total!`: recalcula o total do orçamento ao alterar itens

Exemplo de definição atual:

```ruby
TEMAS = %w[premium classico executivo].freeze

validates :tema, inclusion: { in: TEMAS }
```

---

### `ItemOrcamento`

O item do orçamento continua sendo o centro do fluxo do editor.

Campos frequentemente usados no editor:

- `nome_produto_livre`: substitui o nome do produto em contexto da proposta
- `descricao_item`: descrição livre do item, editável inline
- `posicao_ordem`: ordem visual do item
- `valorunitario`, `quantidade`: base de cálculo de total

Relacionamentos importantes:

```ruby
has_many :fotos, class_name: 'ItemOrcamentoFoto', foreign_key: 'cod_item',
         dependent: :destroy, inverse_of: :item_orcamento

def foto_principal
  fotos.order(:posicao_ordem).first
end
```

A foto principal é usada pelo layout atual; a tabela de fotos permite evoluir para layouts com múltiplas fotos sem quebrar a estrutura atual.

---

### `ItemOrcamentoFoto`

A tabela `item_orcamento_fotos` é a responsável por armazenar as imagens do item dentro do orçamento.

Campos atuais relevantes:

| Campo | Tipo | Uso |
|---|---|---|
| `cod_item` | FK | vínculo com o item do orçamento |
| `foto` | string | imagem enviada via upload do computador |
| `biblioteca_foto_url` | string | URL da imagem já existente na biblioteca do produto |
| `origem` | string | `upload` ou `biblioteca` |
| `posicao_ordem` | integer | ordem da foto no item |
| `posicao_foto` | string | `left` ou `right` |
| `tamanho_foto` | string | `small`, `medium` ou `large` |

Exemplo da model:

```ruby
ORIGENS       = %w[upload biblioteca].freeze
POSICOES_FOTO = %w[left right].freeze
TAMANHOS_FOTO = %w[small medium large].freeze

mount_uploader :foto, ItemOrcamentoFotoUploader

belongs_to :item_orcamento, class_name: 'ItemOrcamento', foreign_key: 'cod_item',
           inverse_of: :fotos

validates :origem,       inclusion: { in: ORIGENS }
validates :posicao_foto, inclusion: { in: POSICOES_FOTO }
validates :tamanho_foto, inclusion: { in: TAMANHOS_FOTO }

default_scope { order(:posicao_ordem) }

def url_exibicao(versao = :medium)
  if origem == "upload" && foto.present?
    foto.send(versao).url
  elsif origem == "biblioteca" && biblioteca_foto_url.present?
    biblioteca_foto_url
  end
end
```

- `origem` define a fonte da imagem.
- `url_exibicao` centraliza a resolução da URL, sem expor ao layout se a imagem é upload ou biblioteca.
- `default_scope` garante ordem consistente das fotos.

---

## Rotas do editor

A configuração atual está em `config/routes.rb` e segue este padrão:

```ruby
resources :orcamentos do
  member do
    post :converter_venda
    get :print
  end

  resource :editor, controller: "orcamento_editor", only: [:show] do
    patch :auto_save, on: :member
    patch :trocar_tema, on: :member
    patch :salvar_link, on: :member
  end

  resources :itens, controller: "orcamento_itens", only: [:create, :update, :destroy] do
    member do
      patch :toggle_posicao_foto
      patch :trocar_tamanho_foto
      patch :remover_foto
    end
    collection do
      patch :reordenar
    end
  end
end
```

### Rotas principais do editor

| Método | Rota | Controller#Action | Uso |
|---|---|---|---|
| GET | `/collaborators_backoffice/orcamentos/:orcamento_id/editor` | `orcamento_editor#show` | Abre o editor visual |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/editor/auto_save` | `orcamento_editor#auto_save` | Salva título, validade, desconto e observações |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/editor/trocar_tema` | `orcamento_editor#trocar_tema` | Troca o tema e renderiza o documento atualizado |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/editor/salvar_link` | `orcamento_editor#salvar_link` | Salva as opções do link público (proteção por senha e validade) |
| POST | `/collaborators_backoffice/orcamentos/:orcamento_id/itens` | `orcamento_itens#create` | Adiciona novo item |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/itens/:id` | `orcamento_itens#update` | Atualiza item, preço, nome, descrição e foto |
| DELETE | `/collaborators_backoffice/orcamentos/:orcamento_id/itens/:id` | `orcamento_itens#destroy` | Remove item |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/itens/:id/toggle_posicao_foto` | `orcamento_itens#toggle_posicao_foto` | Alterna foto para esquerda/direita |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/itens/:id/trocar_tamanho_foto` | `orcamento_itens#trocar_tamanho_foto` | Cicla `small → medium → large` |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/itens/:id/remover_foto` | `orcamento_itens#remover_foto` | Remove a foto do item |
| PATCH | `/collaborators_backoffice/orcamentos/:orcamento_id/itens/reordenar` | `orcamento_itens#reordenar` | Salva nova ordem após drag-and-drop |

### Biblioteca de imagens do produto

```ruby
resources :produto_imagens, only: [:index, :create, :edit, :destroy] do
  get :biblioteca, on: :collection
  post :salvar_da_orcamento, on: :collection
end
```

| Método | Rota | Controller#Action | Uso |
|---|---|---|---|
| GET | `/collaborators_backoffice/produto_imagens/biblioteca` | `produto_imagens#biblioteca` | Modal de imagens do produto no editor |
| POST | `/collaborators_backoffice/produto_imagens/salvar_da_orcamento` | `produto_imagens#salvar_da_orcamento` | Salva a foto do orçamento na biblioteca do produto |

---

## Controladores e responsabilidades

### `CollaboratorsBackoffice::OrcamentoEditorController`

Controller principal do editor:

- `show`: prepara o `OrcamentoRendererService`
- `auto_save`: salva campos editáveis do orçamento via AJAX
- `trocar_tema`: valida o tema, atualiza o registro e renderiza o documento novamente
- `salvar_link`: persiste as opções de compartilhamento do link público — proteção por senha, senha customizada de 4 dígitos e validade do link (24h / 48h / 7 dias / até a validade do orçamento)

Dados permitidos no `auto_save` atual:

```ruby
def auto_save_params
  params.require(:orcamento).permit(:titulo, :data_validade, :desconto, :observacoes,
                                    :cor_primaria, :cor_secundaria, :cor_destaque)
end
```

Observação: a implementação atual persiste também as cores do tema por orçamento, mas o `JS` do editor de fato envia os campos de título, validade, desconto e observações no save automático. Isso é importante para não confundir o que a UI realmente persiste em tempo real.

---

### `CollaboratorsBackoffice::OrcamentoItensController`

Responsável por todo o ciclo de vida dos itens editáveis do orçamento.

Ações atuais:

- `create`: cria um item vazio e devolve o `item_html` + `totais_html`
- `update`: trata upload de foto, imagem da biblioteca, e edição de campos inline
- `destroy`: remove item e recalcula total
- `toggle_posicao_foto`: alterna `left`/`right`
- `trocar_tamanho_foto`: percorre `small → medium → large`
- `remover_foto`: remove todas as fotos do item
- `reordenar`: atualiza `posicao_ordem` em lote

Fluxo de upload da imagem:

1. o arquivo é enviado pelo input do item
2. o `item` recebe `params[:item][:foto]`
3. a foto é salva em `ItemOrcamentoFoto` com `origem = "upload"`
4. o card do item é renderizado novamente via JSON
5. se o item tiver `cod_produto` e `cod_cor`, é exibido um modal perguntando se deve salvar também na biblioteca

---

### `CollaboratorsBackoffice::ProdutoImagensController`

Ações relevantes para o editor:

- `salvar_da_orcamento`: recebe arquivo + `cod_produto` + `cod_cor`, redimensiona para `1920x1080` com MiniMagick, converte para JPEG e grava uma imagem na biblioteca do produto
- `biblioteca`: entrega a lista de imagens para o modal do editor, com busca e paginação

O processamento atual segue assim:

```ruby
imagem_minimagick = MiniMagick::Image.read(arquivo.tempfile)
imagem_minimagick.resize "1920x1080"

produto_imagem = ProdutoImagem.new(produto: produto, cor: cor)
produto_imagem.imagem.attach(
  io: StringIO.new(imagem_minimagick.to_blob),
  filename: nome_arquivo,
  content_type: 'image/jpeg'
)
```

A intenção é manter o uso do produto e da cor como base para organização da biblioteca, sem duplicar os arquivos quando a imagem já existe no produto.

---

## Arquitetura do renderer do tema

A lógica de apresentação foi separada em um serviço e em um registry de temas.

```ruby
module OrcamentoRenderer
  class TemaRegistry
    TEMAS = {
      "premium"   => Temas::PremiumTema,
      "classico"  => Temas::ClassicoTema,
      "executivo" => Temas::ExecutivoTema
    }.freeze

    def self.resolve(name)
      klass = TEMAS[name.to_s]
      (klass || TEMAS["premium"]).new
    end
  end
end
```

```ruby
class OrcamentoRendererService
  attr_reader :orcamento, :tema, :itens

  def initialize(orcamento)
    @orcamento = orcamento
    @tema      = OrcamentoRenderer::TemaRegistry.resolve(orcamento.tema)
    @itens     = orcamento.itens_orcamentos.includes(:produto, :cor).order(:posicao_ordem)
  end
end
```

O serviço centraliza:

- resolução do tema ativo
- ordenação dos itens
- renderização do documento em HTML para o editor

---

## Front-end do editor

O JS principal está em `app/assets/javascripts/orcamento_editor.js`.

Funcionalidades implementadas no cliente:

- auto-save com debounce
- adição de item via AJAX
- edição inline de campos de texto e preço
- remoção de item
- upload de imagem
- escolha de imagem da biblioteca
- troca de tema
- toggle desktop/mobile
- drag-and-drop para reordenação
- atualização dos totais em tempo real

Exemplo de comportamento importante:

```javascript
window.editorAutoSave = function () {
  marcandoSalvando();
  clearTimeout(autoSaveTimer);
  autoSaveTimer = setTimeout(_doAutoSave, 800);
};
```

E também:

```javascript
window.editorTrocarTema = function (tema) {
  fetch(trocarTemaUrl(), {
    method: "POST",
    headers: { "X-CSRF-Token": csrf(), "Accept": "text/html" },
    body: fd
  }).then(r => r.text()).then(html => {
    const preview = document.getElementById("preview-documento");
    if (preview) preview.innerHTML = html;
  });
};
```

O editor usa JavaScript vanilla e não depende de Stimulus/Turbo para executar suas ações principais.

---

## Fluxo básico do usuário

1. Abre a tela do editor no orçamento.
2. Edita título, validade, desconto e observações; o sistema salva automaticamente.
3. Adiciona itens e preenche nome/descrição/preço inline.
4. Escolhe uma foto via upload ou biblioteca de imagens do produto.
5. Ajusta a posição e o tamanho da foto.
6. Reordena os itens com drag-and-drop.
7. Troca o tema e visualiza a proposta com o layout atualizado.
8. O total e os campos do documento são re-renderizados sem refresh completo.

---

## Compartilhamento do link público

O orçamento pode ser compartilhado com o cliente por um link público (`orcamentos_publicos#show`), que renderiza o documento com o tema ativo. O editor tem um botão **Compartilhar** na toolbar que abre um modal com as opções de proteção e validade desse link.

### Proteção por senha (opcional)

Por padrão, o link nasce **aberto** — o cliente acessa direto, sem senha. O vendedor pode, opcionalmente, protegê-lo:

- O modal tem um switch **"Proteger com senha"**.
- Quando ativado, o campo de senha já vem **pré-preenchido com os 4 últimos dígitos do telefone do cliente** (via `Orcamento#sugestao_senha`), mas é **editável**.
- A senha é sempre **4 dígitos numéricos** — o JS filtra a entrada e a model valida o formato e normaliza (remove não-dígitos, corta em 4).
- Quando o link não é protegido, o `OrcamentosPublicosController` pula a verificação de senha e exibe o documento diretamente.

Campos e métodos relevantes na model:

```ruby
# Link aberto por padrão
add_column :orcamentos, :link_protegido, :boolean, default: false, null: false
add_column :orcamentos, :senha_publica_customizada, :string, limit: 4

def link_requer_senha?
  link_protegido?
end

# Senha efetiva: a customizada, se definida; senão, a sugestão do telefone
def senha_publica
  return senha_publica_customizada if senha_publica_customizada.present?
  sugestao_senha
end

def senha_publica_valida?(senha)
  return true unless link_requer_senha?
  senha.to_s.gsub(/\D/, '') == senha_publica.to_s.gsub(/\D/, '')
end
```

> **O que a senha protege:** apenas a confidencialidade da proposta (preços e itens) caso o link seja repassado a terceiros. Não protege nada crítico do sistema, por isso o padrão é aberto.

### Validade do link (escolha)

O mesmo modal permite escolher por quanto tempo o link fica acessível:

| Opção | Efeito |
|---|---|
| 24 horas | `link_expira_em = Time.current + 24h` |
| 48 horas | `link_expira_em = Time.current + 48h` |
| 7 dias | `link_expira_em = Time.current + 7d` |
| Até a validade do orçamento | `link_expira_em = nil` (comportamento antigo) |

A expiração explícita (`link_expira_em`) tem **prioridade** sobre a lógica antiga. Quando é `nil`, o sistema volta a usar `data_validade`/`status` — então orçamentos antigos continuam funcionando sem mudança:

```ruby
add_column :orcamentos, :link_expira_em, :datetime

def link_expirado?
  # Prioridade 1: expiração explícita escolhida pelo vendedor
  return Time.current > link_expira_em if link_expira_em.present?

  # Prioridade 2 (comportamento antigo): validade do orçamento
  return Date.current > data_validade.to_date if data_validade.present?

  status != 'pendente'
end

def aplicar_validade_link(opcao)
  # "24h" / "48h" / "7d" definem link_expira_em; "orcamento" (ou vazio) limpa
end
```

### Fluxo do modal (front-end)

O JS (`orcamento_editor.js`) preenche o modal a partir de data-attributes ao abrir (`show.bs.modal`), filtra a senha para 4 dígitos e envia tudo via PATCH para a action `salvar_link`, exibindo feedback de sucesso/erro sem recarregar a página. A rota é lida do `data-salvar-link-url` do container `#orcamento-editor`.

### Envio por WhatsApp

Na listagem (`orcamentos/index.html.erb`), o botão de WhatsApp monta a mensagem com o link público. Quando o link é protegido, a **senha é incluída automaticamente** na mensagem, para o cliente conseguir abrir.

---

## Observações finais

A implementação atual já está mais próxima de um editor de proposta com UX de desktop do que de um sistema totalmente genérico. O código foi desenhado para ser evolutivo, com a separação entre:

- dados do orçamento
- dados do item
- fotos do item
- biblioteca de imagens do produto
- renderização visual por tema

Esse desenho facilita futuras melhorias, como:

- múltiplas fotos por item em layout de galeria
- temas adicionais
- mais opções de personalização visual
- exportação direta para PDF ou impressão via backend


O `OrcamentoItensController` precisará de uma action para gerenciar múltiplas fotos (adicionar, remover, reordenar fotos individuais de um item), mas o modelo de dados já está pronto.

---

## Observações importantes

- **`nome_produto_livre`** — se preenchido, substitui o nome do produto cadastrado no sistema. Permite adaptar o nome para cada proposta sem alterar o cadastro.
- **Auto-save** — título, validade, desconto e observações salvam automaticamente com debounce de 800ms. Não há botão "Salvar" explícito para esses campos.
- **`recalcular_total!`** — chamado após qualquer alteração de item pelo editor. O form padrão de edição (`_form.html.erb`) calcula o total via JavaScript no frontend e envia o `valortotal` já calculado no submit.
- **Subtotal no show** — calculado somando `valor_total` de cada item diretamente, não derivado do `valortotal` salvo, garantindo que sempre bate com os itens exibidos na tela.
- **Link público** — nasce aberto (sem senha). A proteção por senha é opcional e sugere os 4 últimos dígitos do telefone, podendo ser alterada pelo vendedor. A validade é escolhível (24h / 48h / 7 dias / até a validade do orçamento); quando não escolhida, mantém o comportamento antigo baseado em `data_validade`/`status`.
