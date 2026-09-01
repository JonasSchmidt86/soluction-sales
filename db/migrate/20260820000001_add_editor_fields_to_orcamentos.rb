# frozen_string_literal: true

class AddEditorFieldsToOrcamentos < ActiveRecord::Migration[7.1]
  def change
    # Campos visuais do orçamento (tema e cores)
    add_column :orcamentos, :titulo, :string
    add_column :orcamentos, :tema, :string, default: "premium", null: false
    add_column :orcamentos, :cor_primaria, :string, default: "#2c2c2c", null: false
    add_column :orcamentos, :cor_secundaria, :string, default: "#666666", null: false
    add_column :orcamentos, :cor_destaque, :string, default: "#8b7355", null: false

    # Campos de edição inline por item (sem foto — gerenciada em item_orcamento_fotos)
    add_column :itens_orcamentos, :descricao_item, :string
    add_column :itens_orcamentos, :posicao_ordem, :integer, default: 0, null: false
    add_column :itens_orcamentos, :nome_produto_livre, :string
  end
end
