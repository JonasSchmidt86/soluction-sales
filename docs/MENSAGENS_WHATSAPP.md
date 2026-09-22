# Mensagens de WhatsApp (aniversariantes e afins)

Recurso que permite cadastrar, **por empresa**, mensagens prontas de WhatsApp
com marcadores dinâmicos (ex.: `{{nome}}`). Ao clicar no ícone do WhatsApp de um
cliente (widget de aniversariantes do dashboard e relatório de aniversariantes),
abre um menu para escolher entre "só abrir a conversa" ou uma das mensagens
cadastradas — já com o nome do cliente substituído.

- **Cadastro (backoffice):** `Collaborators Backoffice > Mensagens de WhatsApp`
- **Onde aparece:** widget "Aniversariantes da Semana" (dashboard) e relatório
  de aniversariantes.

---

## Visão geral

- Cada empresa tem **N** mensagens (tabela `whatsapp_messages`), isoladas por
  `empresa_id` (multi-tenant, igual ao resto do sistema).
- O texto aceita **emojis e quebras de linha** e marcadores `{{...}}` no estilo
  do `custom_report`, trocados pelos dados do cliente na hora de montar o link.
- O clique **não envia** nada automaticamente: abre o WhatsApp com a mensagem já
  digitada; quem aperta "enviar" é o atendente.
- O campo `categoria` já existe no banco (default `geral`) para, no futuro,
  filtrar quais mensagens aparecem em cada tela. **Hoje todas as ativas aparecem.**

---

## Esquema do banco

### `whatsapp_messages`
| Coluna | Tipo | Observações |
|---|---|---|
| `empresa_id` | integer | Referencia `empresa.cod_empresa`. Sem FK automática porque a PK de `empresa` é `cod_empresa`, não `id`. |
| `titulo` | string | Rótulo curto exibido no menu (ex.: "Feliz aniversário com desconto"). Obrigatório. |
| `mensagem` | text | O texto da mensagem, com emojis, quebras de linha e marcadores `{{...}}`. Obrigatório. |
| `categoria` | string | Default `geral`. Reservado para filtro futuro por contexto. |
| `ativo` | boolean | Default `true`. Só mensagens ativas aparecem no menu. |
| `ordem` | integer | Default `0`. Ordena as opções no menu. |

Índices: `(empresa_id, ativo, ordem)` e `(empresa_id, categoria)`.

Migration: `db/migrate/20260922000001_create_whatsapp_messages.rb`

---

## Models

### `WhatsappMessage` (`app/models/whatsapp_message.rb`)
- `belongs_to :empresa` (via `foreign_key: empresa_id`, `primary_key: cod_empresa`).
- Validações: `titulo` e `mensagem` presentes.
- Scopes: `ativas` (ativo + ordenado), `da_empresa(cod)`, `da_categoria(cat)`.
- Constante `PLACEHOLDERS`: mapa `chave => descrição` dos marcadores suportados.
- `render(nome_cliente:, nome_empresa:)`: troca os marcadores pelos valores e
  **capitaliza o nome** mantendo preposições em minúsculo (ex.: `MARIA DA SILVA`
  → `Maria da Silva`). `{{nome}}` usa o primeiro nome; `{{nome_completo}}`, o
  nome inteiro. Acentos são preservados (`mb_chars.capitalize`).

**Marcadores suportados hoje:**

| Marcador | Vira |
|---|---|
| `{{nome}}` | Primeiro nome do cliente (capitalizado). |
| `{{nome_completo}}` | Nome completo (capitalizado, preposições minúsculas). |
| `{{empresa}}` | Nome da loja/empresa logada. |

### `Empresa` (alteração)
- `has_many :whatsapp_messages` (via `cod_empresa`, `dependent: :destroy`).

---

## Backoffice (cadastro)

- **Rota:** `resources :whatsapp_messages, only: [:index, :new, :create, :edit, :update, :destroy]`
  no namespace `collaborators_backoffice`.
- **Controller:** `CollaboratorsBackoffice::WhatsappMessagesController`
  - CRUD completo escopado por empresa: todas as queries usam
    `da_empresa(current_collaborator.cod_empresa)` e o `create` seta
    `empresa_id` automaticamente. Um colaborador nunca vê/edita mensagem de
    outra empresa.
  - **Restrito a administradores** via `before_action :require_admin!`
    (`access_control.admin?`, ou seja, `permissao.nivel == 1`). Não está no
    `CONTROLLER_RESOURCE_MAP`; a proteção real é o `require_admin!`. Mesmo padrão
    do `CompanyLinkPagesController`.
- **Views** (`app/views/collaborators_backoffice/whatsapp_messages/`)
  - `index.html.erb`: lista as mensagens (ordem, título, prévia, ativa) com menu
    de editar/excluir. Excluir usa `method: :delete` + `data: { confirm: ... }`
    (o app usa **rails-ujs**, não Turbo).
  - `_form.html.erb`: título, ordem, switch "ativa" e `textarea` para a mensagem
    (emojis e quebras de linha). Mostra a lista de marcadores disponíveis.
  - `new.html.erb` / `edit.html.erb`: renderizam o `_form`.

### Item no menu (só ADMIN)
No menu lateral (`_menu_lateral.html.erb`), item **"Mensagens de WhatsApp"**,
dentro do bloco `if current_collaborator.funcionario.permissao.nivel == 1`
(mesmo bloco de "Páginas de Links"), portanto só aparece para administradores.

---

## O botão/menu de WhatsApp

O helper `whatsapp_client_button(fone_zap, nome_cliente)`
(`app/helpers/collaborators_backoffice_helper.rb`) gera o elemento clicável:

- **Sem mensagens cadastradas:** um link simples que só abre a conversa.
- **Com mensagens:** um menu com "Só abrir conversa" + uma opção por mensagem
  ativa, cada uma com os marcadores já substituídos para aquele cliente.

Helpers auxiliares no mesmo arquivo:
- `whatsapp_messages_ativas`: carrega as mensagens ativas da empresa (memoizado
  por request, para não repetir query por linha da tabela).
- `whatsapp_link(fone_zap, mensagem = nil)`: monta a URL (ver abaixo).

### Menu que não é cortado
O menu **não** usa o dropdown do Bootstrap. Um script no layout
(`collaborators_backoffice.html.erb`) move o menu para o `<body>` ao abrir e o
posiciona com `position: fixed` logo abaixo do ícone (ou **acima**, quando não há
espaço embaixo — caso do último item do relatório). Isso resolve dois problemas:

1. **Clipping:** contêineres com `overflow` (`.widget-scroll` do dashboard e
   `.table-responsive` do relatório) cortavam o menu.
2. **Abrir fora da tela:** o último registro abria o menu para baixo e ele saía
   da viewport.

O menu fecha ao clicar fora, escolher uma opção, rolar, redimensionar ou apertar
Esc. Estilos: classes `.wa-menu`, `.wa-menu-item`, `.wa-menu-divider`,
`.wa-menu-toggle`, `.wa-menu-wrap` (definidas no `<style>` do layout).

---

## URL do WhatsApp (encoding e comportamento)

`whatsapp_link` monta a URL assim:

- Limpa o número (`(45)99996-7722` → só dígitos) e garante o DDI `55` (Brasil).
- **Sem mensagem:** `https://wa.me/<numero>`.
- **Com mensagem:** `https://api.whatsapp.com/send?phone=<numero>&text=<texto>`.

Cuidados de encoding (para não sair `�` no lugar de emoji/acento):
- O texto é forçado para **UTF-8** antes de escapar
  (`encode("UTF-8", invalid: :replace, undef: :replace)`).
- Usa `ERB::Util.url_encode` (percent-encoding com `%20`, não `+`), que o
  WhatsApp trata de forma mais consistente para caracteres multibyte/emoji.
- Normaliza `\r\n` → `\n` (remove o CR do textarea, que alguns clientes rejeitam).

### "É a API do WhatsApp? Envia sozinho?"
**Não.** Apesar do nome `api.whatsapp.com`, isso **não** é a API oficial de envio.
É apenas um link "click to chat": abre o WhatsApp com a conversa e o texto **já
preenchido**; o atendente ainda precisa apertar enviar. Envio automático de
verdade só com a **API oficial do WhatsApp Business** (produto pago, com templates
aprovados) — fora do escopo deste recurso.

### Abre igual em qualquer lugar?
Sim. Quem decide para onde ir é o próprio WhatsApp, conforme o dispositivo de quem
clica — o link é sempre o mesmo:
- **Celular:** abre o app com a mensagem pronta.
- **PC com WhatsApp Desktop:** normalmente abre o app desktop.
- **PC sem o app / navegador:** abre no WhatsApp Web (pede QR code se não estiver
  logado; depois de logar, a mensagem aparece pronta).

O texto com emojis/acentos vai junto em todos os casos.

---

## Relatório de aniversariantes (paginação + filtro)

O relatório (`report/rep_aniversariantes`) segue o padrão dos demais relatórios:

- **Paginação:** 30 por página (com opções 30/40/70/150/"Todas"). Como os dados
  vêm de SQL cru (`exec_query`), a paginação usa
  `Kaminari.paginate_array(registros).page(params[:page]).per(per_page)` — mesmo
  padrão do `caixa_controller`. "Todas" traz tudo sem paginar.
- **Filtro por nome:** campo `term` que adiciona `AND UPPER(p.nome) LIKE :term`
  ao SQL (bind seguro).
- **Rodapé:** `page_entries_info` à esquerda e `paginate` alinhado à direita.

Arquivos: `app/controllers/collaborators_backoffice/report/rep_aniversariantes_controller.rb`
e `app/views/collaborators_backoffice/report/rep_aniversariantes/index.html.erb`.

> Nota: o widget do dashboard mostra os próximos 7 dias e **não** é paginado
> (fonte: `DashboardDataService#aniversariantes`). A paginação é só do relatório.

---

## Como usar (passo a passo)

1. Vá em `Mensagens de WhatsApp > Nova Mensagem` (precisa ser admin).
2. Dê um **título** curto (aparece no menu).
3. Escreva a **mensagem** usando emojis, quebras de linha e marcadores. Ex.:
   ```
   Olá! {{nome}} 🥳
   A {{empresa}} deseja um feliz aniversário! 🎁
   ```
4. Ajuste **ordem** e deixe **ativa**.
5. No dashboard (widget) ou no relatório de aniversariantes, clique no ícone do
   WhatsApp de um cliente e escolha a mensagem. O WhatsApp abre com o texto
   personalizado pronto para enviar.

Se a empresa não tiver nenhuma mensagem ativa, o ícone abre a conversa
diretamente (sem menu).

---

## Arquivos envolvidos

**Migration**
- `db/migrate/20260922000001_create_whatsapp_messages.rb`

**Models**
- `app/models/whatsapp_message.rb` (novo)
- `app/models/empresa.rb` (`has_many :whatsapp_messages`)

**Backoffice**
- `app/controllers/collaborators_backoffice/whatsapp_messages_controller.rb` (novo)
- `app/views/collaborators_backoffice/whatsapp_messages/*` (novos)

**Botão/menu e URL**
- `app/helpers/collaborators_backoffice_helper.rb`
  (`whatsapp_client_button`, `whatsapp_link`, `whatsapp_messages_ativas`)
- `app/views/collaborators_backoffice/welcome/widgets/_aniversariantes.html.erb`
- `app/views/collaborators_backoffice/report/rep_aniversariantes/index.html.erb`
- `app/views/layouts/collaborators_backoffice.html.erb` (CSS `.wa-menu*` + script)

**Relatório (paginação/filtro)**
- `app/controllers/collaborators_backoffice/report/rep_aniversariantes_controller.rb`

**Menu**
- `app/views/layouts/shared/_menu_lateral.html.erb` (item "Mensagens de WhatsApp", admin-only)

**Rotas**
- `config/routes.rb` (`resources :whatsapp_messages`)
