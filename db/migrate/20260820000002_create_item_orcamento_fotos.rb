# frozen_string_literal: true

class CreateItemOrcamentoFotos < ActiveRecord::Migration[7.1]
  def change
    create_table :item_orcamento_fotos do |t|
      t.bigint :cod_item, null: false
      t.string :foto                              # upload direto (CarrierWave)
      t.string :biblioteca_foto_url               # imagem da biblioteca (Active Storage)
      t.string :origem, default: "upload", null: false  # 'upload' ou 'biblioteca'
      t.string :posicao_foto, default: "left", null: false  # posição no layout: left ou right
      t.string :tamanho_foto, default: "medium", null: false  # small, medium ou large
      t.integer :posicao_ordem, default: 0, null: false

      t.timestamps
    end

    add_foreign_key :item_orcamento_fotos, :itens_orcamentos,
                    column: :cod_item, primary_key: :cod_item
  end
end
