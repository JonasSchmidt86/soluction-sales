# Tema de Orçamento "Ambientes" (paisagem) — TRABALHO ARQUIVADO

> **Status:** cancelado/removido do código em 05/09/2026. Este documento é o
> registro completo do que foi feito, com o conteúdo integral de cada arquivo,
> para permitir **recriar exatamente o mesmo resultado** no futuro.
>
> Foi removido do sistema (código + rollback do banco de dev) porque o layout
> ainda não estava do jeito desejado. Nada disso chegou a produção (nunca foi
> commitado). Quando quiser retomar, siga a seção "COMO RECRIAR".

---

## 1. VISÃO GERAL DO QUE FOI CONSTRUÍDO

Um novo **tema selecionável** de orçamento chamado `ambientes`, com layout de
catálogo de decoração, coexistindo com os temas existentes (premium, classico,
executivo) **sem alterá-los**.

Funcionalidades entregues:

- **Novo tema `ambientes`** no dropdown do editor (cor `#6b8e5a`).
- **Orientação retrato/paisagem** por orçamento (padrão paisagem no tema
  ambientes). Toggle na toolbar; PDF em Landscape/Portrait conforme escolha.
- **Ambientes**: agrupador de itens (Sala, Quarto, etc.). Podem repetir nome
  ("Sala" 2x) para dar opções diferentes ao mesmo cômodo.
  - Cada ambiente tem uma **foto grande** (upload do computador ou da biblioteca
    de produtos), redimensionável arrastando.
  - Nome e descrição livres.
- **Itens do ambiente**: cada item pode ter **até 3 fotos**. Cada foto em uma
  **linha** com 3 colunas: [ foto | descrição livre | valor ].
  - Foto redimensionável arrastando.
  - Descrição e valor **opcionais** (no editor sempre aparecem; no público/PDF só
    aparecem se preenchidos).
  - Valor é **por foto** (não por item). O total do orçamento soma os valores das fotos.
- **Página de Capa**: logo da loja centralizado.
- **Página de Abertura** (editável/ocultável): logo + descrição livre
  (ex: "Consultoria Personalizada / Projeto Residencial") + linha "Cliente:" +
  linha "Consultora:" (nome do funcionário do orçamento).
- **Divisória por ambiente**: página com o nome do ambiente centralizado.
- Aplicado de forma consistente no **editor**, no **link público** e no **PDF** (WickedPdf).

### Arquitetura (resumo técnico)

- Tema = objeto Ruby resolvido por `OrcamentoRenderer::TemaRegistry` (em
  `app/services/orcamento_renderer_service.rb`). Herda de `TemaBase`.
- Renderização: `_documento.html.erb` (mestre, usado por editor E PDF) tem branch:
  se `tema.name == "ambientes"` renderiza `_documento_ambientes`.
- Orientação é do **orçamento** (`orcamento.orientacao`), não do tema.
- Fotos de item já usavam `has_many :fotos` (ItemOrcamentoFoto) — foi só exposto N fotos.
- Foto grande do ambiente usa **CarrierWave** (uploader próprio), storage :file.

---

## 2. MODELO DE DADOS (migrações)

Foram criadas 6 migrações (timestamps `202609050000001` a `06`). **Uma delas
(a 000004) NÃO é exclusiva do tema** — ela tornou `itens_orcamentos.cod_produto`
nullable, o que o editor de orçamento já assume (itens "livres" sem produto).
Se for recriar só o tema ambientes, avalie manter a 000004 mesmo assim, pois o
editor cria itens com `cod_produto: nil`.

### Tabela nova: `orcamento_ambientes` (PK `cod_ambiente`)
| coluna | tipo | notas |
|---|---|---|
| cod_orcamento | bigint, null false | FK -> orcamentos |
| nome | string(120) | ex: "Sala" |
| descricao | text | livre |
| foto | string | CarrierWave (upload) |
| foto_url | string | URL da biblioteca |
| origem | string default "upload" | upload \| biblioteca |
| foto_largura | integer | px (redimensionamento) |
| foto_altura | integer | px |
| posicao_ordem | integer default 0 | |
| timestamps | | |
- index [cod_orcamento, posicao_ordem]; FK -> orcamentos.

### `itens_orcamentos`: + `cod_ambiente` (bigint, nullable)
- index; FK -> orcamento_ambientes (on_delete: nullify).

### `item_orcamento_fotos`: + `descricao`(text) + `largura`(int) + `altura`(int) + `valor`(decimal 12,2)

### `itens_orcamentos.cod_produto`: NOT NULL -> nullable (migração 000004)

### `orcamentos`: + `orientacao`(string(20) default "paisagem" null false) + `abertura_descricao`(text) + `abertura_visivel`(boolean default true null false)

---

## 3. ROLLBACK REALIZADO (para referência)

```bash
# desfazer as 6 migrações (na ordem inversa), em desenvolvimento:
bundle exec rails db:rollback STEP=6
# depois os arquivos de migração foram removidos e o schema.rb voltou ao estado anterior.
```

---

## 4. CONTEÚDO INTEGRAL DAS MIGRAÇÕES

### db/migrate/20260905000001_create_orcamento_ambientes.rb
```ruby
# frozen_string_literal: true

class CreateOrcamentoAmbientes < ActiveRecord::Migration[7.1]
  def change
    create_table :orcamento_ambientes, primary_key: :cod_ambiente do |t|
      t.bigint  :cod_orcamento, null: false
      t.string  :nome, limit: 120                      # ex: "Sala", "Quarto"
      t.text    :descricao                             # texto livre do ambiente
      t.string  :foto                                  # upload direto (CarrierWave)
      t.string  :foto_url                              # imagem escolhida da biblioteca
      t.string  :origem, default: "upload", null: false # 'upload' ou 'biblioteca'
      t.integer :foto_largura                          # px — redimensionamento livre da foto grande
      t.integer :foto_altura                           # px
      t.integer :posicao_ordem, default: 0, null: false

      t.timestamps
    end

    add_foreign_key :orcamento_ambientes, :orcamentos,
                    column: :cod_orcamento, primary_key: :cod_orcamento

    add_index :orcamento_ambientes, [:cod_orcamento, :posicao_ordem]
  end
end
```

### db/migrate/20260905000002_add_cod_ambiente_to_itens_orcamentos.rb
```ruby
# frozen_string_literal: true

class AddCodAmbienteToItensOrcamentos < ActiveRecord::Migration[7.1]
  def change
    # Nullable: só o tema "ambientes" agrupa itens; os demais temas ignoram.
    add_column :itens_orcamentos, :cod_ambiente, :bigint
    add_index  :itens_orcamentos, :cod_ambiente

    add_foreign_key :itens_orcamentos, :orcamento_ambientes,
                    column: :cod_ambiente, primary_key: :cod_ambiente,
                    on_delete: :nullify
  end
end
```

### db/migrate/20260905000003_add_descricao_e_dimensoes_to_item_orcamento_fotos.rb
```ruby
# frozen_string_literal: true

class AddDescricaoEDimensoesToItemOrcamentoFotos < ActiveRecord::Migration[7.1]
  def change
    add_column :item_orcamento_fotos, :descricao, :text     # descrição livre por imagem
    add_column :item_orcamento_fotos, :largura,   :integer  # px — redimensionamento livre
    add_column :item_orcamento_fotos, :altura,    :integer  # px
  end
end
```

### db/migrate/20260905000004_allow_null_cod_produto_on_itens_orcamentos.rb
```ruby
# frozen_string_literal: true

# O editor de orçamento cria itens "livres" (sem produto cadastrado), preenchendo
# apenas nome/descrição/preço. A coluna cod_produto era NOT NULL, impedindo esse
# fluxo. Tornamos nullable — não afeta itens já existentes (todos têm produto).
class AllowNullCodProdutoOnItensOrcamentos < ActiveRecord::Migration[7.1]
  def up
    change_column_null :itens_orcamentos, :cod_produto, true
  end

  def down
    change_column_null :itens_orcamentos, :cod_produto, false
  end
end
```

### db/migrate/20260905000005_add_valor_to_item_orcamento_fotos.rb
```ruby
# frozen_string_literal: true

class AddValorToItemOrcamentoFotos < ActiveRecord::Migration[7.1]
  def change
    add_column :item_orcamento_fotos, :valor, :decimal, precision: 12, scale: 2
  end
end
```

### db/migrate/20260905000006_add_orientacao_e_abertura_to_orcamentos.rb
```ruby
# frozen_string_literal: true

class AddOrientacaoEAberturaToOrcamentos < ActiveRecord::Migration[7.1]
  def change
    add_column :orcamentos, :orientacao, :string, limit: 20, default: "paisagem", null: false
    add_column :orcamentos, :abertura_descricao, :text
    add_column :orcamentos, :abertura_visivel, :boolean, default: true, null: false
  end
end
```

---

## 5. ALTERAÇÕES EM ARQUIVOS EXISTENTES

### app/models/orcamento.rb
1. Constante TEMAS ganhou `ambientes`:
   ```ruby
   TEMAS = %w[premium classico executivo ambientes].freeze
   TEMA_AMBIENTES = "ambientes"
   ORIENTACOES = %w[retrato paisagem].freeze
   ```
2. Associação:
   ```ruby
   has_many :ambientes, class_name: 'OrcamentoAmbiente', foreign_key: 'cod_orcamento',
            inverse_of: :orcamento, dependent: :destroy
   ```
3. Validação:
   ```ruby
   validates :orientacao, inclusion: { in: ORIENTACOES }, allow_blank: true
   ```
4. Métodos adicionados:
   ```ruby
   def tema_ambientes?
     tema == TEMA_AMBIENTES
   end

   def orientacao_efetiva
     return "retrato" unless tema_ambientes?
     ORIENTACOES.include?(orientacao) ? orientacao : "paisagem"
   end

   def paisagem?; orientacao_efetiva == "paisagem"; end
   def retrato?;  orientacao_efetiva == "retrato";  end

   def abertura_visivel?
     tema_ambientes? && abertura_visivel != false
   end

   # e total dos ambientes (soma valores das fotos):
   def total_ambientes
     itens_orcamentos.includes(:fotos).sum { |i| i.valor_fotos }
   end
   ```
5. `tem_fotos?` foi adaptado para considerar fotos de ambiente quando tema ambientes:
   ```ruby
   def tem_fotos?
     if tema_ambientes?
       ambientes.any?(&:foto_presente?) ||
         itens_orcamentos.includes(:fotos).any? { |item| item.fotos.any? }
     else
       itens_orcamentos.includes(:fotos).any? { |item| item.foto_principal.present? }
     end
   end
   ```

### app/models/item_orcamento.rb
```ruby
belongs_to :ambiente, class_name: 'OrcamentoAmbiente', foreign_key: 'cod_ambiente',
           inverse_of: :itens, optional: true

def fotos_ordenadas
  fotos.order(:posicao_ordem)
end

def valor_fotos
  fotos.sum { |f| f.valor.to_f }
end

def nome_exibicao
  nome_produto_livre.presence || produto&.nome
end
```

### app/models/item_orcamento_foto.rb
```ruby
def presente?
  (origem == "upload" && foto.present?) ||
    (origem == "biblioteca" && biblioteca_foto_url.present?)
end
```
(Colunas descricao/largura/altura/valor vêm das migrações — atributos automáticos.)

### app/services/orcamento_renderer_service.rb
- Registrar o tema em `OrcamentoRenderer::TemaRegistry::TEMAS`:
  `"ambientes" => Temas::AmbientesTema`
- No initialize, `itens` passou a `.includes(:produto, :cor, :fotos)`.
- Métodos adicionados no service:
  ```ruby
  def paisagem?; orcamento.paisagem?; end
  def orientacao; orcamento.orientacao_efetiva; end

  def ambientes
    @ambientes ||= orcamento.ambientes
                            .includes(itens: [:produto, :cor, :fotos])
                            .order(:posicao_ordem)
  end

  def itens_sem_ambiente
    @itens_sem_ambiente ||= itens.select { |i| i.cod_ambiente.blank? }
  end
  ```

### app/services/orcamento_renderer/tema_base.rb
- Adicionado `def paisagem?; false; end` (default; herdado pelos temas).

### app/controllers/collaborators_backoffice/orcamento_editor_controller.rb
- `auto_save_params` ganhou: `:orientacao, :abertura_descricao, :abertura_visivel`.

### app/controllers/collaborators_backoffice/orcamento_itens_controller.rb
- `before_action :set_item` inclui `:adicionar_foto`.
- `item_params` ganhou `:cod_ambiente`.
- `create` aceita `params[:cod_ambiente]`: se presente, cria o item no ambiente e
  retorna a partial `orcamento_editor/ambiente_item`.
- `render_item_json`: se `@item.cod_ambiente` presente, retorna a partial
  `ambiente_item` em vez de `item_card`.
- Nova action `adicionar_foto`: anexa MAIS uma foto ao item (upload OU
  produto_imagem_id) sem substituir as existentes.

### app/controllers/orcamentos_publicos_controller.rb
- No `pdf`: `orientacao = renderer.paisagem? ? 'Landscape' : 'Portrait'` e passa
  `orientation: orientacao` ao WickedPdf.

### config/routes.rb — dentro de `resources :orcamentos do`
```ruby
resources :itens, controller: "orcamento_itens", only: [:create, :update, :destroy] do
  member do
    patch :toggle_posicao_foto
    patch :trocar_tamanho_foto
    patch :remover_foto
    patch :adicionar_foto           # NOVO
  end
  collection do
    patch :reordenar
  end
  resources :fotos, controller: "orcamento_item_fotos", only: [:update, :destroy]  # NOVO
end

# NOVO bloco:
resources :ambientes, controller: "orcamento_ambientes",
          only: [:create, :update, :destroy] do
  member do
    patch :remover_foto
    patch :associar_item
  end
  collection do
    patch :reordenar
  end
end
```

### Views existentes ajustadas
- `orcamento_renderer/_documento.html.erb`: no topo, branch
  `<% if tema.name == "ambientes" %>` renderiza `documento_ambientes`, senão o
  layout antigo (fechar com `<% end %>` no final).
- `orcamento_editor/_documento_inline.html.erb`: mesmo branch com
  `renderer.tema.name == "ambientes"` -> `documento_ambientes_inline`.
- `orcamento_editor/show.html.erb`:
  - `cores_tema` ganhou `"ambientes" => "#6b8e5a"`.
  - Toggle de orientação (`#orientacao-toggle` com `#btn-retrato`/`#btn-paisagem`),
    visível só no tema ambientes.
  - `#preview-frame` class = `@orcamento.paisagem? ? 'preview-landscape' : 'preview-desktop'`.
  - CSS adicionado: `.preview-landscape { width:297mm; ... }`, `.ambiente-editavel`,
    `.foto-redim`, `.resize-handle`.
- `orcamento_renderer/orcamentos_publicos/show.html.erb` (público): `.visualizador-externo`
  width condicional (`renderer.paisagem? ? '297mm' : '210mm'`; min-height invertido).
- `orcamentos/show.html.erb` e `orcamentos/print.html.erb`: a coluna que fazia
  `item.produto.nome` passou a `item.nome_exibicao.presence || '-'` (para itens sem produto).

---

## 6. ARQUIVOS NOVOS (conteúdo integral)

### app/uploaders/orcamento_ambiente_foto_uploader.rb
```ruby
class OrcamentoAmbienteFotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "uploads/orcamentos/ambientes/#{model.id}"
  end

  version :large do
    process resize_to_limit: [1600, 1200]
  end

  version :medium do
    process resize_to_limit: [900, 700]
  end

  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end
end
```

### app/models/orcamento_ambiente.rb
```ruby
# frozen_string_literal: true

class OrcamentoAmbiente < ApplicationRecord
  self.table_name = "orcamento_ambientes"
  self.primary_key = "cod_ambiente"

  ORIGENS = %w[upload biblioteca].freeze

  mount_uploader :foto, OrcamentoAmbienteFotoUploader

  belongs_to :orcamento, class_name: "Orcamento", foreign_key: "cod_orcamento",
             inverse_of: :ambientes

  has_many :itens, class_name: "ItemOrcamento", foreign_key: "cod_ambiente",
           inverse_of: :ambiente, dependent: :nullify

  validates :origem, inclusion: { in: ORIGENS }

  default_scope { order(:posicao_ordem) }

  def foto_url_exibicao(versao = :large)
    if origem == "upload" && foto.present?
      foto.send(versao).url
    elsif origem == "biblioteca" && foto_url.present?
      foto_url
    end
  end

  def foto_presente?
    (origem == "upload" && foto.present?) || (origem == "biblioteca" && foto_url.present?)
  end

  def nome_exibicao
    nome.presence || "Ambiente"
  end
end
```

### app/services/orcamento_renderer/temas/ambientes_tema.rb
```ruby
# frozen_string_literal: true

module OrcamentoRenderer
  module Temas
    class AmbientesTema < TemaBase
      def name = "ambientes"
      def paisagem? = true

      def dimensoes_foto
        { "small" => "150px", "medium" => "210px", "large" => "280px" }
      end

      def estilos_documento(orcamento)
        { font_family: "'Segoe UI', system-ui, sans-serif", line_height: "1.5",
          background: "#ffffff", color: "#2c2c2c" }
      end

      def estilos_header(orcamento)
        { background: "#ffffff", color: orcamento.cor_primaria,
          padding: "2.4rem 3rem 1.6rem",
          line_color: "rgba(44,44,44,0.12)", muted_color: "rgba(44,44,44,0.7)",
          logo_invert: false }
      end

      def estilos_produto(orcamento)
        { margin_bottom: "1.2rem", padding: "0", background: "transparent",
          border: "none", border_radius: "0" }
      end

      def estilos_footer(orcamento)
        { background: "#fafafa", color: "#999999", padding: "1.4rem 3rem",
          border_top: "1px solid #f0f0f0",
          line_color: "rgba(44,44,44,0.12)", muted_color: "rgba(44,44,44,0.7)" }
      end
    end
  end
end
```

### app/controllers/collaborators_backoffice/orcamento_ambientes_controller.rb
```ruby
# frozen_string_literal: true

class CollaboratorsBackoffice::OrcamentoAmbientesController < CollaboratorsBackofficeController
  before_action :set_orcamento
  before_action :set_ambiente, only: [:update, :destroy, :remover_foto, :associar_item]

  def create
    posicao = (@orcamento.ambientes.maximum(:posicao_ordem) || -1) + 1
    @ambiente = @orcamento.ambientes.build(
      nome:          params.dig(:ambiente, :nome).presence || "Novo ambiente",
      posicao_ordem: posicao,
      origem:        "upload"
    )
    if @ambiente.save
      render json: { success: true, ambiente_id: @ambiente.cod_ambiente, ambiente_html: _ambiente_editor_html(@ambiente) }
    else
      render json: { success: false, errors: @ambiente.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if params.dig(:ambiente, :foto).present?
      @ambiente.origem = "upload"; @ambiente.foto_url = nil
      @ambiente.foto = params[:ambiente][:foto]
      @ambiente.save!(validate: false)
      return render_ambiente_json
    end
    if params[:produto_imagem_id].present?
      imagem = ProdutoImagem.find(params[:produto_imagem_id])
      if imagem.imagem.attached?
        url = Rails.application.routes.url_helpers.rails_blob_path(imagem.imagem, only_path: true)
        @ambiente.remove_foto = true if @ambiente.foto.present?
        @ambiente.origem = "biblioteca"; @ambiente.foto_url = url
        @ambiente.save!(validate: false)
      end
      return render_ambiente_json
    end
    if @ambiente.update(ambiente_params)
      render_ambiente_json
    else
      render json: { success: false, errors: @ambiente.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @ambiente.destroy!
    render json: { success: true }
  end

  def remover_foto
    @ambiente.remove_foto = true if @ambiente.foto.present?
    @ambiente.foto_url = nil; @ambiente.origem = "upload"
    @ambiente.save!(validate: false)
    render_ambiente_json
  end

  def associar_item
    item = @orcamento.itens_orcamentos.find(params[:item_id])
    item.update_columns(cod_ambiente: params[:desassociar].present? ? nil : @ambiente.cod_ambiente)
    render json: { success: true }
  end

  def reordenar
    (params[:posicoes] || []).each_with_index do |amb_id, idx|
      @orcamento.ambientes.where(cod_ambiente: amb_id).update_all(posicao_ordem: idx)
    end
    head :ok
  end

  private

  def set_orcamento; @orcamento = Orcamento.find(params[:orcamento_id]); end
  def set_ambiente;  @ambiente = @orcamento.ambientes.find(params[:id]); end
  def ambiente_params
    params.require(:ambiente).permit(:nome, :descricao, :foto_largura, :foto_altura)
  end

  def _ambiente_editor_html(ambiente)
    render_to_string(partial: "collaborators_backoffice/orcamento_editor/ambiente_card",
                     locals: { ambiente: ambiente, orcamento: @orcamento }, formats: [:html])
  end

  def render_ambiente_json
    render json: { success: true, ambiente_id: @ambiente.cod_ambiente, ambiente_html: _ambiente_editor_html(@ambiente.reload) }
  end
end
```

### app/controllers/collaborators_backoffice/orcamento_item_fotos_controller.rb
```ruby
# frozen_string_literal: true

class CollaboratorsBackoffice::OrcamentoItemFotosController < CollaboratorsBackofficeController
  before_action :set_orcamento
  before_action :set_item
  before_action :set_foto

  def update
    if @foto.update(foto_params)
      render json: { success: true, foto_id: @foto.id }
    else
      render json: { success: false, errors: @foto.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @foto.destroy!
    render json: { success: true }
  end

  private

  def set_orcamento; @orcamento = Orcamento.find(params[:orcamento_id]); end
  def set_item; @item = @orcamento.itens_orcamentos.find(params[:iten_id]); end
  def set_foto; @foto = @item.fotos.find(params[:id]); end
  def foto_params
    params.require(:foto).permit(:descricao, :valor, :largura, :altura, :posicao_ordem)
  end
end
```

### app/views/collaborators_backoffice/orcamento_renderer/temas/_ambientes.html.erb
```erb
<style>
  .orcamento-tema-ambientes { color: #2c2c2c; }
  .orcamento-tema-ambientes .orcamento-header { border-bottom: none; position: relative; text-align: center; }
  .orcamento-tema-ambientes .orcamento-header::after {
    content: ""; position: absolute; bottom: 0; left: 3rem; right: 3rem; height: 1px;
    background: linear-gradient(to right, transparent, #e0e0e0, transparent);
  }
  .orcamento-tema-ambientes .orcamento-header h1 {
    font-weight: 300; letter-spacing: .22em; color: <%= orcamento.cor_primaria %>; text-transform: uppercase;
  }
  .orcamento-tema-ambientes .amb-quebra { page-break-before: always; break-before: page; }
  .orcamento-tema-ambientes .amb-pagina {
    display: flex; align-items: center; justify-content: center; min-height: 80vh;
    page-break-inside: avoid; break-inside: avoid;
  }
  .amb-ambiente {
    display: flex; gap: 2rem; align-items: stretch; padding: 2rem 3rem;
    border-bottom: 1px solid #f0f0f0; page-break-inside: avoid; break-inside: avoid;
  }
  .amb-ambiente + .amb-ambiente { page-break-before: always; }
  .amb-foto-grande {
    flex: 0 0 auto; border-radius: 8px; overflow: hidden; background: #f5f5f5;
    box-shadow: 0 6px 26px rgba(0,0,0,.08); position: relative;
  }
  .amb-foto-grande img { width: 100%; height: 100%; object-fit: cover; display: block; }
  .amb-nome {
    font-size: 1.4rem; font-weight: 300; letter-spacing: .04em; color: <%= orcamento.cor_primaria %>;
    margin: 0 0 .3rem; text-transform: lowercase;
  }
  .amb-descricao { font-size: .82rem; line-height: 1.6; opacity: .7; margin: 0 0 1rem; white-space: pre-wrap; }
  .amb-itens { flex: 1 1 auto; min-width: 0; display: flex; flex-direction: column; gap: .8rem; }
  .amb-itens-lista, .amb-itens-grid { display: flex; flex-direction: column; gap: 1rem; }
  .amb-item-linha { display: flex; align-items: flex-start; gap: 1rem; padding-bottom: .9rem; border-bottom: 1px solid #f2f2f2; }
  .amb-item-linha:last-child { border-bottom: none; }
  .amb-item-foto { border-radius: 6px; overflow: hidden; background: #f5f5f5; box-shadow: 0 3px 14px rgba(0,0,0,.06); }
  .amb-item-foto img { width: 100%; height: 100%; object-fit: cover; display: block; }
  .amb-item-desc { font-size: .78rem; line-height: 1.55; white-space: pre-wrap; opacity: .85; align-self: center; }
  .amb-item-preco { font-size: 1rem; font-weight: 700; color: <%= orcamento.cor_destaque %>; letter-spacing: -.01em; align-self: center; }
  .orcamento-tema-ambientes .orcamento-totais { background: transparent; border-top: 1px solid #f0f0f0; }
  .orcamento-tema-ambientes .orcamento-footer { background: #fafafa; border-top: 1px solid #f0f0f0; }
</style>
```

### app/views/collaborators_backoffice/orcamento_renderer/_capa.html.erb
```erb
<% nome_loja = orcamento.empresa.pessoa.apelido.presence || orcamento.empresa.pessoa.nome.presence || "Loja" %>
<div class="amb-capa" style="display:flex; align-items:center; justify-content:center; text-align:center; min-height:60vh; padding:3rem;">
  <div>
    <%= image_tag "/assets/logo-b9f22b9da9fb78162609a90b790c13247458ca278e2fc6f61ce3411af6b2977f.png",
                  alt: nome_loja, style: "max-height:160px; width:auto; display:block; margin:0 auto;" %>
  </div>
</div>
```
> Nota: o caminho do logo é o mesmo asset fingerprintado usado em `_header.html.erb`.
> Ao recriar, confirme o nome atual do asset.

### app/views/collaborators_backoffice/orcamento_renderer/_abertura.html.erb
```erb
<% nome_loja  = orcamento.empresa.pessoa.apelido.presence || orcamento.empresa.pessoa.nome.presence || "Loja" %>
<% cliente    = orcamento.pessoa&.nome.presence %>
<% consultora = (orcamento.funcionario&.pessoa_nome.presence || orcamento.funcionario&.usuario.presence) %>
<div class="amb-abertura" style="display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; min-height:55vh; padding:3rem; gap:1.6rem;">
  <%= image_tag "/assets/logo-b9f22b9da9fb78162609a90b790c13247458ca278e2fc6f61ce3411af6b2977f.png",
                alt: nome_loja, style: "max-height:110px; width:auto; display:block; margin:0 auto .5rem;" %>
  <% if orcamento.abertura_descricao.present? %>
    <div style="font-size:1.05rem; line-height:1.7; white-space:pre-wrap; color:<%= orcamento.cor_primaria %>; max-width:640px;">
      <%= orcamento.abertura_descricao %>
    </div>
  <% end %>
  <div style="display:flex; flex-direction:column; gap:.5rem; font-size:.95rem;">
    <% if cliente.present? %><div><span style="font-weight:700;">Cliente:</span> <%= cliente %></div><% end %>
    <% if consultora.present? %><div><span style="font-weight:700;">Consultora:</span> <%= consultora %></div><% end %>
  </div>
</div>
```

### app/views/collaborators_backoffice/orcamento_renderer/_ambiente_divisor.html.erb
```erb
<% nome = ambiente.nome.presence %>
<% if nome.present? %>
  <div class="amb-divisor" style="display:flex; align-items:center; justify-content:center; text-align:center; min-height:45vh; padding:3rem;">
    <h2 style="font-size:2rem; font-weight:300; letter-spacing:.06em; color:<%= orcamento.cor_primaria %>; margin:0;"><%= nome %></h2>
  </div>
<% end %>
```

### app/views/collaborators_backoffice/orcamento_renderer/_totais_ambientes.html.erb
```erb
<% total = orcamento.total_ambientes %>
<% if total.to_f > 0 %>
  <div class="orcamento-totais" style="padding:1.6rem 3rem; border-top:1px solid rgba(128,128,128,.12);">
    <div style="display:flex; justify-content:flex-end; align-items:baseline; gap:1rem;">
      <span style="font-size:.72rem; opacity:.5; text-transform:uppercase; letter-spacing:.05em;">Total</span>
      <span style="font-size:1.6rem; font-weight:800; letter-spacing:-.03em;">
        <%= number_to_currency(total, unit: "R$ ", separator: ",", delimiter: ".") %>
      </span>
    </div>
  </div>
<% end %>
```

### app/views/collaborators_backoffice/orcamento_renderer/_ambiente_render.html.erb
```erb
<% foto_largura = (ambiente.foto_largura.presence || 420).to_i %>
<% foto_altura  = (ambiente.foto_altura.presence || 520).to_i %>
<% itens = ambiente.itens.to_a %>
<div class="amb-ambiente">
  <% foto_grande = ambiente.foto_url_exibicao %>
  <% if foto_grande.present? %>
    <div class="amb-foto-grande" style="width:<%= foto_largura %>px; height:<%= foto_altura %>px;">
      <img src="<%= foto_grande %>" alt="<%= ambiente.nome_exibicao %>">
    </div>
  <% end %>
  <div class="amb-itens">
    <% if ambiente.nome.present? %><h2 class="amb-nome"><%= ambiente.nome %></h2><% end %>
    <% if ambiente.descricao.present? %><p class="amb-descricao"><%= ambiente.descricao %></p><% end %>
    <div class="amb-itens-lista">
      <% itens.each do |item| %>
        <% item.fotos_ordenadas.select(&:presente?).first(3).each do |foto| %>
          <% larg = (foto.largura.presence || 200).to_i %>
          <% alt  = (foto.altura.presence  || 160).to_i %>
          <% descricao = foto.descricao.presence %>
          <% valor = foto.valor.to_f %>
          <div class="amb-item-linha">
            <div class="amb-item-foto" style="width:<%= larg %>px; height:<%= alt %>px; flex-shrink:0;">
              <img src="<%= foto.url_exibicao %>" alt="">
            </div>
            <% if descricao.present? %>
              <div class="amb-item-desc" style="flex:1; min-width:0;"><%= descricao %></div>
            <% else %>
              <div style="flex:1; min-width:0;"></div>
            <% end %>
            <% if valor > 0 %>
              <div class="amb-item-preco" style="flex-shrink:0; width:120px; text-align:right;">
                <%= number_to_currency(valor, unit: "R$ ", separator: ",", delimiter: ".") %>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
  </div>
</div>
```

### app/views/collaborators_backoffice/orcamento_renderer/_documento_ambientes.html.erb
```erb
<% doc = tema.estilos_documento(orcamento) %>
<% ambientes = orcamento.ambientes.includes(itens: [:produto, :cor, :fotos]).order(:posicao_ordem) %>
<div class="orcamento-documento orcamento-tema-<%= tema.name %>"
     style="font-family:<%= doc[:font_family] %>; line-height:<%= doc[:line_height] %>; background:<%= doc[:background] %>; color:<%= doc[:color] %>; -webkit-font-smoothing:antialiased;">
  <%= render "collaborators_backoffice/orcamento_renderer/temas/ambientes", orcamento: orcamento, tema: tema %>
  <div class="amb-pagina">
    <%= render "collaborators_backoffice/orcamento_renderer/capa", orcamento: orcamento %>
  </div>
  <% if orcamento.abertura_visivel? %>
    <div class="amb-pagina amb-quebra">
      <%= render "collaborators_backoffice/orcamento_renderer/abertura", orcamento: orcamento %>
    </div>
  <% end %>
  <% if orcamento.titulo.present? %>
    <div class="orcamento-titulo amb-quebra" style="padding:1.6rem 3rem .4rem; text-align:center;">
      <h2 style="font-size:1.05rem; font-weight:500; color:<%= orcamento.cor_destaque %>; margin:0; letter-spacing:.04em;"><%= orcamento.titulo %></h2>
    </div>
  <% end %>
  <% if ambientes.any? %>
    <% ambientes.each do |ambiente| %>
      <div class="amb-pagina amb-quebra">
        <%= render "collaborators_backoffice/orcamento_renderer/ambiente_divisor", ambiente: ambiente, orcamento: orcamento %>
      </div>
      <div class="amb-quebra">
        <%= render "collaborators_backoffice/orcamento_renderer/ambiente_render", ambiente: ambiente, orcamento: orcamento, tema: tema %>
      </div>
    <% end %>
  <% else %>
    <div style="text-align:center; padding:4rem 1rem; color:rgba(128,128,128,.4); font-size:.88rem;">Nenhum ambiente adicionado ainda.</div>
  <% end %>
  <%= render "collaborators_backoffice/orcamento_renderer/totais_ambientes", orcamento: orcamento %>
  <%= render "collaborators_backoffice/orcamento_renderer/observacoes", orcamento: orcamento %>
  <%= render "collaborators_backoffice/orcamento_renderer/footer", orcamento: orcamento, tema: tema %>
</div>
```

### app/views/collaborators_backoffice/orcamento_editor/_ambiente_card.html.erb
```erb
<% amb_update_url   = collaborators_backoffice_orcamento_ambiente_path(orcamento, ambiente) %>
<% amb_remover_foto = remover_foto_collaborators_backoffice_orcamento_ambiente_path(orcamento, ambiente) %>
<% amb_destroy_url  = collaborators_backoffice_orcamento_ambiente_path(orcamento, ambiente) %>
<% foto_grande      = ambiente.foto_url_exibicao %>
<% fg_larg = (ambiente.foto_largura.presence || 420).to_i %>
<% fg_alt  = (ambiente.foto_altura.presence  || 520).to_i %>
<div id="ambiente-card-<%= ambiente.cod_ambiente %>" class="amb-ambiente ambiente-editavel"
     data-ambiente-id="<%= ambiente.cod_ambiente %>" data-update-url="<%= amb_update_url %>">
  <div style="flex-shrink:0;">
    <div class="amb-foto-grande foto-redim" style="width:<%= fg_larg %>px; height:<%= fg_alt %>px; position:relative;"
         data-redim-tipo="ambiente" data-redim-url="<%= amb_update_url %>">
      <% if foto_grande.present? %>
        <img src="<%= foto_grande %>" alt="<%= ambiente.nome_exibicao %>">
      <% else %>
        <div style="width:100%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;opacity:.3;gap:.4rem;">
          <svg width="42" height="42" fill="currentColor" viewBox="0 0 16 16"><path d="M6.002 5.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z"/><path d="M2.002 1a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2h-12zm12 1a1 1 0 0 1 1 1v6.5l-3.777-1.947a.5.5 0 0 0-.577.093l-3.71 3.71-2.66-1.772a.5.5 0 0 0-.63.062L1.002 12V3a1 1 0 0 1 1-1h12z"/></svg>
          <span style="font-size:.72rem;">Foto do ambiente</span>
        </div>
      <% end %>
      <% if foto_grande.present? %>
        <div class="resize-handle" data-alvo="foto-grande" title="Arraste para redimensionar"></div>
      <% end %>
    </div>
    <div class="d-flex gap-1 mt-2" style="max-width:<%= fg_larg %>px; flex-wrap:wrap;">
      <button type="button" class="btn btn-sm btn-outline-primary" style="font-size:.72rem;"
              onclick="editorUploadFotoAmb(<%= ambiente.cod_ambiente %>)"><i class="fa fa-upload me-1"></i> Do computador</button>
      <button type="button" class="btn btn-sm btn-outline-primary" style="font-size:.72rem;"
              onclick="editorAbrirBibliotecaAmb(<%= ambiente.cod_ambiente %>, '<%= amb_update_url %>')"><i class="fa fa-images me-1"></i> Da biblioteca</button>
      <% if ambiente.foto_presente? %>
        <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:.72rem;"
                onclick="editorRemoverFotoAmb(<%= ambiente.cod_ambiente %>, '<%= amb_remover_foto %>')"><i class="fa fa-trash"></i></button>
      <% end %>
    </div>
    <form id="form-foto-amb-<%= ambiente.cod_ambiente %>" style="display:none;">
      <input type="file" id="file-foto-amb-<%= ambiente.cod_ambiente %>" accept="image/*"
             onchange="editorSubmitFotoAmb(<%= ambiente.cod_ambiente %>, '<%= amb_update_url %>')">
    </form>
  </div>
  <div class="amb-itens" style="position:relative;">
    <button type="button" class="btn btn-sm btn-light shadow-sm text-danger"
            style="position:absolute; top:0; right:0; font-size:.65rem; padding:2px 6px; z-index:5;"
            title="Remover ambiente" onclick="editorRemoverAmbiente(<%= ambiente.cod_ambiente %>, '<%= amb_destroy_url %>')"><i class="fa fa-trash"></i></button>
    <input type="text" value="<%= ambiente.nome %>" class="amb-nome input-inline" placeholder="Nome do ambiente (ex: Sala)" style="max-width:70%;"
           oninput="editorSalvarCampoAmb(<%= ambiente.cod_ambiente %>, 'nome', this.value, '<%= amb_update_url %>')">
    <textarea class="amb-descricao textarea-inline" placeholder="Descrição do ambiente..." rows="2"
              oninput="editorSalvarCampoAmb(<%= ambiente.cod_ambiente %>, 'descricao', this.value, '<%= amb_update_url %>')"><%= ambiente.descricao %></textarea>
    <div class="amb-itens-grid" id="amb-itens-grid-<%= ambiente.cod_ambiente %>">
      <% ambiente.itens.each do |item| %>
        <%= render "collaborators_backoffice/orcamento_editor/ambiente_item", item: item, ambiente: ambiente, orcamento: orcamento %>
      <% end %>
    </div>
    <div class="mt-2">
      <button type="button" class="btn btn-sm btn-outline-secondary" style="font-size:.72rem;"
              onclick="editorAdicionarItemAmbiente(<%= ambiente.cod_ambiente %>)"><i class="fa fa-plus me-1"></i> Adicionar produto</button>
    </div>
  </div>
</div>
```

### app/views/collaborators_backoffice/orcamento_editor/_ambiente_item.html.erb
```erb
<% item_update_url = collaborators_backoffice_orcamento_iten_path(orcamento, item) %>
<% adicionar_foto_url = adicionar_foto_collaborators_backoffice_orcamento_iten_path(orcamento, item) %>
<% destroy_item_url = collaborators_backoffice_orcamento_iten_path(orcamento, item) %>
<% fotos = item.fotos_ordenadas.to_a %>
<div id="amb-item-<%= item.cod_item %>" class="amb-item item-ambiente-editavel" data-item-id="<%= item.cod_item %>"
     style="position:relative; border:1px dashed rgba(0,0,0,.08); border-radius:8px; padding:.7rem; width:100%;">
  <button type="button" class="btn btn-sm btn-light text-danger"
          style="position:absolute; top:-8px; right:-8px; font-size:.6rem; padding:1px 5px; border-radius:50%; z-index:6;"
          title="Remover produto do orçamento" onclick="editorRemoverItem(<%= item.cod_item %>, '<%= destroy_item_url %>')"><i class="fa fa-times"></i></button>
  <% fotos.first(3).each do |foto| %>
    <% larg = (foto.largura.presence || 200).to_i %>
    <% alt  = (foto.altura.presence  || 160).to_i %>
    <% foto_update_url = collaborators_backoffice_orcamento_iten_foto_path(orcamento, item, foto) %>
    <div class="amb-item-linha" style="display:flex; align-items:flex-start; gap:.9rem; margin-bottom:.7rem;">
      <div class="amb-item-foto foto-redim" style="width:<%= larg %>px; height:<%= alt %>px; position:relative; flex-shrink:0;"
           data-redim-tipo="foto-item" data-redim-url="<%= foto_update_url %>">
        <% if foto.presente? %><img src="<%= foto.url_exibicao %>" alt=""><% end %>
        <button type="button" class="btn btn-sm btn-light text-danger"
                style="position:absolute; top:2px; right:2px; font-size:.55rem; padding:0 4px; z-index:6;"
                title="Remover foto" onclick="editorRemoverFotoItemAmb(<%= item.cod_item %>, '<%= foto_update_url %>')"><i class="fa fa-times"></i></button>
        <div class="resize-handle" data-alvo="foto-item" title="Arraste para redimensionar"></div>
      </div>
      <div style="flex:1; min-width:0;">
        <textarea class="amb-item-desc textarea-inline" placeholder="Descrição / dimensões / acabamento (opcional)"
                  rows="4" style="font-size:.74rem; width:100%;"
                  oninput="editorSalvarDescFoto(<%= foto.id %>, this.value, '<%= foto_update_url %>')"><%= foto.descricao %></textarea>
      </div>
      <div style="flex-shrink:0; width:120px; text-align:right;">
        <span style="font-size:.62rem; opacity:.5; display:block;">Valor (opcional)</span>
        <div style="display:flex; align-items:baseline; gap:.2rem; justify-content:flex-end;">
          <span style="font-size:.62rem; opacity:.5;">R$</span>
          <input type="text" value="<%= foto.valor.to_f > 0 ? number_with_precision(foto.valor, precision: 2, separator: ',', delimiter: '.') : '' %>"
                 class="input-inline money2" inputmode="decimal" placeholder="0,00"
                 style="font-size:.85rem; font-weight:700; width:90px; text-align:right; color:<%= orcamento.cor_destaque %>;"
                 onchange="editorSalvarValorFoto(<%= foto.id %>, this.value, '<%= foto_update_url %>')">
        </div>
      </div>
    </div>
  <% end %>
  <% if fotos.size < 3 %>
    <div style="display:flex; gap:.3rem; flex-wrap:wrap;">
      <button type="button" class="btn btn-sm btn-outline-secondary" style="font-size:.68rem;"
              onclick="editorAdicionarFotoItem(<%= item.cod_item %>, '<%= adicionar_foto_url %>')"><i class="fa fa-upload me-1"></i> Adicionar foto</button>
      <button type="button" class="btn btn-sm btn-outline-secondary" style="font-size:.68rem;"
              onclick="editorAddFotoBiblioteca(<%= item.cod_item %>, '<%= adicionar_foto_url %>')"><i class="fa fa-images me-1"></i> Da biblioteca</button>
    </div>
    <form id="form-add-foto-<%= item.cod_item %>" style="display:none;">
      <input type="file" id="file-add-foto-<%= item.cod_item %>" accept="image/*"
             onchange="editorSubmitAddFoto(<%= item.cod_item %>, '<%= adicionar_foto_url %>')">
    </form>
  <% end %>
  <input type="text" value="<%= item.nome_produto_livre.presence || item.produto&.nome %>"
         class="input-inline" placeholder="Nome do produto (opcional)" style="font-size:.78rem; font-weight:600; margin-top:.4rem;"
         oninput="editorSalvarCampo(<%= item.cod_item %>, 'nome_produto_livre', this.value, '<%= item_update_url %>', true)">
</div>
```

### app/views/collaborators_backoffice/orcamento_editor/_documento_ambientes_inline.html.erb
(conteúdo: idêntico ao read-only mas com o bloco editável de abertura — switch
`#abertura-visivel` -> `editorToggleAbertura`, textarea `#campo-abertura-descricao`
-> `editorSalvarAbertura` — e cards editáveis `_ambiente_card`, botão "Adicionar
ambiente" -> `editorAdicionarAmbiente`, e `#preview-totais` com `totais_ambientes`.
Ver estrutura completa no histórico; segue o mesmo padrão do documento read-only.)

---

## 7. JAVASCRIPT (app/assets/javascripts/orcamento_editor.js)

Funções globais adicionadas ao IIFE existente (todas via fetch + FormData + CSRF,
padrão do arquivo):

- `editorTrocarOrientacao(orientacao)` — troca classe do #preview-frame
  (preview-landscape/preview-desktop), marca botões ativos, salva via `_salvarCampoOrcamento("orientacao", ...)`.
- `editorToggleAbertura(visivel)` — opacidade do #abertura-preview + salva `abertura_visivel`.
- `editorSalvarAbertura(valor)` — debounce 600ms, salva `abertura_descricao`.
- `_salvarCampoOrcamento(campo, valor)` — POST para `autoSaveUrl()` com `orcamento[campo]`.
- Bloco Ambientes:
  - `editorAdicionarAmbiente()` / `editorRemoverAmbiente(id, url)` / `editorSalvarCampoAmb(id, campo, valor, url)`
  - Foto grande: `editorUploadFotoAmb(id)`, `editorSubmitFotoAmb(id, url)`, `editorRemoverFotoAmb(id, url)`, `editorAbrirBibliotecaAmb(id, url)`
  - Item no ambiente: `editorAdicionarItemAmbiente(ambId)`, `editorAdicionarFotoItem(itemId, url)`, `editorSubmitAddFoto(itemId, url)`,
    `editorRemoverFotoItemAmb(itemId, fotoUrl)` (faz location.reload), `editorSalvarDescFoto(fotoId, valor, url)`,
    `editorSalvarValorFoto(fotoId, valor, url)`, `editorAddFotoBiblioteca(itemId, url)`
  - `_substituirAmbiente(id, html)`, `_substituirItemAmbiente(id, html)`
  - Redimensionar arrastando: `_setupResizeAll()`, `_iniciarResize(e)` (mousedown/mousemove/mouseup),
    `_salvarDimensao(box)` — salva `ambiente[foto_largura/foto_altura]` ou `foto[largura/altura]` conforme `data-redim-tipo`.
  - `editorSelecionarDaBiblioteca` foi estendida para 3 fluxos: adicionar foto de item (biblioteca),
    foto grande do ambiente, e o fluxo original (foto principal de item de outros temas).
- `editorTrocarTema` passou a mostrar/ocultar `#orientacao-toggle` e ajustar o frame quando tema=ambientes.
- CSS no show.html.erb: `.preview-landscape{width:297mm;...}`, `.ambiente-editavel`, `.foto-redim`,
  `.resize-handle{position:absolute;right:2px;bottom:2px;width:16px;height:16px;background:rgba(52,152,219,.9);border:2px solid #fff;border-radius:3px;cursor:nwse-resize;...}`.

---

## 8. COMO RECRIAR (passo a passo)

1. Recriar as 6 migrações da seção 4 (mesmos nomes/conteúdo) e rodar `bundle exec rails db:migrate`.
2. Criar os arquivos novos da seção 6 (uploader, model, tema, 2 controllers) e da seção 6 (partials de view).
3. Criar os partials do editor da seção 7 (_ambiente_card, _ambiente_item, _documento_ambientes_inline).
4. Aplicar as alterações da seção 5 nos arquivos existentes (models, service, tema_base, controllers, routes, views).
5. Adicionar as funções JS da seção 7 ao `orcamento_editor.js` e o CSS ao `show.html.erb`.
6. Reiniciar o servidor Rails e fazer hard refresh no navegador.

### Verificação rápida (rails runner)
- Confirmar `Orcamento::TEMAS.include?("ambientes")`.
- `OrcamentoRenderer::TemaRegistry.resolve("ambientes")` deve retornar `AmbientesTema`.
- Renderizar `collaborators_backoffice/orcamento_renderer/documento` com um orçamento
  tema ambientes que tenha 1 ambiente + 1 item + fotos.

### Pontos de atenção conhecidos
- `Funcionario` NÃO tem `.nome`; usar `pessoa_nome` (via pessoa) ou `usuario`.
- `itens_orcamentos.cod_produto` precisa ser nullable (o editor cria itens livres).
- `orcamento_ambientes` e `itens_orcamentos` usam PK customizada (`cod_ambiente`, `cod_item`);
  FKs devem declarar `primary_key:` explicitamente.
- Rotas aninhadas `resources :fotos` sob `:itens` geram param `:iten_id` (Rails singulariza "itens" -> "iten").
- Servir imagens: fotos ficam em `public/uploads/...` (CarrierWave storage :file); em produção depende de `RAILS_SERVE_STATIC_FILES`/servidor web.
```
```
