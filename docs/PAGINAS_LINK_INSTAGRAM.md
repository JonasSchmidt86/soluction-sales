# Páginas de Link (Link na Bio / Instagram)

Recurso que gera, para cada empresa, uma página pública no estilo "Linktree"
(link na bio). O objetivo é ter um único link curto para colocar na bio do
Instagram (ou outra rede) onde o cliente escolhe o que fazer: falar no WhatsApp,
ver a localização, acessar o site, abrir outras redes sociais, etc.

- **URL pública:** `https://moveisrosa.shop/l/:slug` (ex.: `/l/moveisrosa_toledo`)
- **Cadastro (backoffice):** `Collaborators Backoffice > Páginas de Links`

---

## Visão geral / modelagem

A informação fica dividida conforme a cardinalidade real do negócio:

- Uma empresa tem **1** site, **1** Instagram, **1** Facebook, etc. → mas isso é
  tratado de forma **flexível** (ver `social_links`), sem campos fixos por rede.
- Uma empresa pode ter **vários** telefones/WhatsApp → reaproveita a tabela
  existente `whatsapp_contacts`.

Por isso o recurso usa **três** tabelas:

| Tabela | Cardinalidade | Papel |
|---|---|---|
| `company_link_pages` | 1 por empresa | A "página" em si (slug, título, descrição, publicado). |
| `social_links` | N por página | Links genéricos (Instagram, site, Maps, TikTok...). |
| `whatsapp_contacts` | N por empresa (já existia) | Telefones/WhatsApp. Ganhou o campo `publicar_link`. |

### Por que `social_links` é genérico?

Em vez de criar colunas fixas (`instagram_url`, `facebook_url`...), cada link é
uma linha na tabela `social_links` com um campo `tipo`. Vantagens:

- Surgiu uma rede nova? Basta cadastrar uma linha nova — **sem migration**.
- Uma rede deixou de existir? Basta apagar a linha.
- O `tipo` só serve para escolher o ícone e a cor na página. Tipo desconhecido
  cai num visual genérico de "link".

---

## Esquema do banco

### `company_link_pages`
| Coluna | Tipo | Observações |
|---|---|---|
| `empresa_id` | integer | Referencia `empresa.cod_empresa`. Único (1 página por empresa). Sem FK automática porque a PK de `empresa` é `cod_empresa`, não `id`. |
| `slug` | string | Único. Parte final da URL pública (`/l/:slug`). |
| `titulo` | string | Título exibido. Se vazio, usa o nome da empresa. |
| `descricao` | string | Subtítulo opcional. |
| `publicado` | boolean | Default `false`. Só páginas publicadas aparecem em `/l/:slug`. |
| `formato_imagem` | string | `redonda` (avatar circular), `quadrada` (imagem grande na largura) ou `cabecalho` (faixa larga no topo com título sobreposto). Define como a imagem do topo é exibida. |
| `cor_fundo_inicio` | string | Cor hex do início do degradê de fundo. Default `#1f2a33`. |
| `cor_fundo_fim` | string | Cor hex do fim do degradê de fundo. Default `#343a40`. Iguais = fundo sólido. |
| `cor_texto` | string | Cor hex do texto (título, descrição, rótulos e texto dos botões). Default `#ffffff`. |

Além das colunas, a página tem uma imagem via Active Storage (`has_one_attached :imagem`,
service `local_custom` → `storage/IMG`). É a foto exibida no topo (fachada da loja,
logo, etc.).

**Recorte interativo (Cropper.js):** no formulário, ao escolher a imagem ela abre
num recortador (proporção fixa 1:1). O usuário arrasta/redimensiona a área desejada
e, no submit, o JS gera o recorte (canvas 400x400) e envia como data URL base64 no
campo virtual `imagem_recortada`. O controller (`anexar_imagem`) prioriza esse
recorte via `attach_imagem_from_data_url`. Se não houver recorte (ex.: JS desligado),
faz fallback para o recorte automático no centro (`resize_imagem_before_attach`,
mesmo padrão do `WhatsappContact`).

O recorte enviado é sempre quadrado (1:1); o `formato_imagem` decide como a página
pública exibe essa imagem:

- `redonda`: avatar circular pequeno centralizado no topo (recorte 1:1, variant 240x240).
- `quadrada`: imagem grande ocupando a largura do cartão, estilo post do Instagram
  (recorte 1:1, variant 640x640, CSS `.banner-quadrado`).
- `cabecalho`: faixa larga edge-to-edge no topo (recorte panorâmico ~2.6:1, variant
  1200x460), com o título/descrição sobrepostos sobre um degradê escuro. O `<body>`
  recebe a classe `tem-cabecalho` e a faixa fica fora do `.wrapper` para ocupar
  100% da largura da tela.

O Cropper.js ajusta a proporção do recorte conforme o formato escolhido (1:1 para
redonda/quadrada, ~2.6:1 para cabeçalho) e reinicia ao trocar o formato.

**Cor de fundo:** as colunas `cor_fundo_inicio` e `cor_fundo_fim` definem o degradê
do fundo da página (via `css_fundo`, aplicado inline no `<body>`). Cores iguais
resultam em fundo sólido. O formato `cabecalho` usa a `cor_fundo_fim` no fim do seu
degradê (variável CSS `--cor-fim`) para a transição da faixa combinar com o fundo.
No formulário há `color_field` para as cores com prévia ao vivo.

**Cor do texto:** a coluna `cor_texto` (`cor_do_texto`) define a cor do título,
descrição, rótulos e texto dos botões, aplicada inline no `<body>` (`color`). Os
botões usam `color: inherit` para herdar essa cor. Escolha claro para fundo escuro
e escuro para fundo claro. Os ícones das redes/WhatsApp têm cores próprias e não são
afetados.

Migration: `db/migrate/20260902120000_create_company_link_pages.rb`

### `social_links`
| Coluna | Tipo | Observações |
|---|---|---|
| `company_link_page_id` | integer | FK para `company_link_pages`. |
| `tipo` | string | `instagram`, `facebook`, `site`, `maps`, `tiktok`, `youtube`, `email`, `telefone`, `outro`. Default `outro`. |
| `titulo` | string | Texto do botão. Se vazio, usa o label do tipo. |
| `url` | string | O link em si. Obrigatório. |
| `ordem` | integer | Ordenação dos botões. Default `0`. |
| `ativo` | boolean | Default `true`. Só links ativos aparecem. |

Migration: `db/migrate/20260902120001_create_social_links.rb`

### `whatsapp_contacts` (alteração)
Campos adicionados à tabela já existente:

| Coluna | Tipo | Observações |
|---|---|---|
| `publicar_link` | boolean | Default `false`. Marca se este número aparece na página. |
| `ordem` | integer | Default `0`. Ordena os botões de WhatsApp. |

Migration: `db/migrate/20260902120002_add_publicar_link_to_whatsapp_contacts.rb`

---

## Models

### `CompanyLinkPage` (`app/models/company_link_page.rb`)
- `belongs_to :empresa` (via `foreign_key: cod_empresa`).
- `has_many :social_links` (ordenados por `ordem`) + `accepts_nested_attributes_for`
  (formulário aninhado com cocoon).
- `has_many :whatsapp_contacts` — **apenas os publicados** da empresa
  (`where(publicar_link: true)`), usados como botões de WhatsApp.
- `slug` é normalizado automaticamente (`before_validation`) via `parameterize`.
  Se o slug vier vazio, é gerado a partir do título ou do nome da empresa.
- As rotas do backoffice usam o `id` normal. A rota pública usa o `slug`, mas via
  `find_by!(slug:)` no controller e `link_page_path(page.slug)` na view (o slug é
  passado explicitamente). Por isso o model **não** sobrescreve `to_param` — fazer
  isso quebraria os helpers de edit/update/destroy do backoffice, que esperam o id.
- Validações: `slug` presente/único/formato; `empresa_id` presente/único.
- Scope: `publicadas`.

### `SocialLink` (`app/models/social_link.rb`)
- `belongs_to :company_link_page`.
- Constante `TIPOS`: mapa `tipo => { label, icon (Font Awesome), cor }`.
  É aqui que se adiciona o visual de um tipo novo, se quiser.
- Helpers: `icon`, `cor`, `label` (com fallback para o tipo `outro`).
- `self.tipos_para_select` alimenta o `<select>` do formulário.
- Scope: `ativos`.

### `WhatsappContact` (alteração)
- `scope :publicados`.
- `whatsapp_url(mensagem = nil)`: limpa o número (`(45)99996-7722` → só dígitos),
  garante o DDI `55` (Brasil) e monta `https://wa.me/55...` com mensagem opcional.

### `Empresa` (alteração)
- `has_one :company_link_page` (via `cod_empresa`, `dependent: :destroy`).

---

## Página pública

- **Rota:** `get 'l/:slug' => 'link_pages#show'` (helper `link_page_path/url`).
- **Controller:** `LinkPagesController#show` (`app/controllers/link_pages_controller.rb`)
  - Busca `CompanyLinkPage.publicadas.find_by!(slug:)`.
  - Carrega `@whatsapp_contacts` (publicados) e `@social_links` (ativos).
  - Renderiza **sem layout** (`render layout: false`).
  - Página não encontrada / não publicada → `404`.
- **View:** `app/views/link_pages/show.html.erb`
  - HTML standalone, mobile-first (não usa os layouts do app).
  - Bootstrap/Font Awesome/Google Fonts via CDN.
  - Ordem de exibição: logo + título + descrição → botões de WhatsApp
    (um por contato publicado; usa a foto do contato como ícone quando houver)
    → botões dos `social_links` (ícone/cor conforme o `tipo`).
  - Mensagem padrão do WhatsApp: "Olá! Vim pelo Instagram e gostaria de mais
    informações."

---

## Backoffice (cadastro)

- **Rota:** `resources :company_link_pages` dentro do namespace
  `collaborators_backoffice`.
- **Controller:** `CollaboratorsBackoffice::CompanyLinkPagesController`
  - CRUD completo (index, new, create, edit, update, destroy).
  - **Restrito a administradores.** Um `before_action :require_admin!` bloqueia
    qualquer colaborador que não seja admin (`access_control.admin?`, ou seja,
    `permissao.nivel == 1`), redirecionando para o welcome com aviso. Esconder o
    link no menu não basta — a proteção real está no controller.
  - Não está no `CONTROLLER_RESOURCE_MAP`; a restrição é feita pelo `require_admin!`.
  - `atualizar_contatos_publicados`: lê `params[:whatsapp_contact_ids]` (checkboxes)
    e atualiza `publicar_link` de cada `WhatsappContact` da empresa.
- **Views** (`app/views/collaborators_backoffice/company_link_pages/`)
  - `index.html.erb`: lista as páginas, com o link público pronto para copiar
    (botão copiar/abrir) e o status de publicação.
  - `_form.html.erb`: empresa, slug (com sugestão automática), título, descrição,
    switch de publicado, checkboxes dos telefones (quais WhatsApp aparecem) e a
    seção de links sociais (cocoon).
  - `_social_link_fields.html.erb`: linha de um `social_link` (tipo, título, url,
    ordem, ativo, remover).
- **Cocoon:** os links sociais são itens aninhados adicionados/removidos
  dinamicamente. O projeto já usa cocoon via asset pipeline
  (`//= require cocoon`), então não há dependência nova.

### Cadastro de WhatsApp (ajuste)
No cadastro existente de `Contatos de WhatsApp` (`whatsapp_contacts`) foram
adicionados:
- Switch "Exibir este número na página de links".
- Campo "Ordem de exibição".
- Coluna "No Link" (Sim/Não) na listagem.

Ou seja, dá para marcar quais números aparecem tanto pelo formulário da página
quanto pelo cadastro do contato.

### Item no menu (só ADMIN)
O acesso ao cadastro fica no menu lateral do backoffice, dentro do grupo
**Cadastros**, no item **"Páginas de Links"**. Esse item é renderizado em
`app/views/layouts/shared/_menu_lateral.html.erb`, dentro do bloco
`if current_collaborator.funcionario.permissao.nivel == 1` (mesmo bloco do item
"Funcionário"), portanto só aparece para administradores.

---

## Como usar (passo a passo)

1. Cadastre os telefones em `Contatos de WhatsApp` (se ainda não existirem).
2. Vá em `Páginas de Links > Nova Página`.
3. Selecione a empresa e salve (isso permite listar os telefones dela).
4. Defina o `slug` (ex.: `moveisrosa_toledo`), título e descrição.
5. Marque quais telefones aparecem na página.
6. Adicione os links sociais (Instagram, site, Maps, etc.).
7. Ligue o switch "Publicar página".
8. Copie o link (`https://moveisrosa.shop/l/moveisrosa_toledo`) e cole na bio do
   Instagram.

---

## Configuração relacionada

Para o link copiável no backoffice sair com o host correto, o
`config/environments/production.rb` define:

```ruby
Rails.application.routes.default_url_options = { host: 'moveisrosa.shop', protocol: 'https' }
```

Isso faz os helpers `_url` (como `link_page_url`) gerarem a URL completa correta
em produção.

---

## Arquivos envolvidos

**Migrations**
- `db/migrate/20260902120000_create_company_link_pages.rb`
- `db/migrate/20260902120001_create_social_links.rb`
- `db/migrate/20260902120002_add_publicar_link_to_whatsapp_contacts.rb`

**Models**
- `app/models/company_link_page.rb` (novo)
- `app/models/social_link.rb` (novo)
- `app/models/whatsapp_contact.rb` (scope + `whatsapp_url`)
- `app/models/empresa.rb` (`has_one :company_link_page`)

**Página pública**
- `app/controllers/link_pages_controller.rb` (novo)
- `app/views/link_pages/show.html.erb` (novo)

**Backoffice**
- `app/controllers/collaborators_backoffice/company_link_pages_controller.rb` (novo)
- `app/views/collaborators_backoffice/company_link_pages/*` (novos)
- `app/controllers/collaborators_backoffice/whatsapp_contacts_controller.rb` (params)
- `app/views/collaborators_backoffice/whatsapp_contacts/shared/_form.html.erb`
- `app/views/collaborators_backoffice/whatsapp_contacts/index.html.erb`

**Menu**
- `app/views/layouts/shared/_menu_lateral.html.erb` (item "Páginas de Links", admin-only)

**Rotas / config**
- `config/routes.rb` (`get 'l/:slug'` e `resources :company_link_pages`)
- `config/environments/production.rb` (`default_url_options`)
