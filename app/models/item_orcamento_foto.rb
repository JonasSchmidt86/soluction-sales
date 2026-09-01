class ItemOrcamentoFoto < ApplicationRecord
  self.table_name = "item_orcamento_fotos"

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
end
