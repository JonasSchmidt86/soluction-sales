class ItemOrcamento < ApplicationRecord
  self.table_name = "itens_orcamentos"
  self.primary_key = "cod_item"

  attr_accessor :produto_nome

  belongs_to :orcamento, class_name: 'Orcamento', foreign_key: 'cod_orcamento', inverse_of: :itens_orcamentos
  belongs_to :produto, class_name: 'Produto', foreign_key: 'cod_produto', optional: true
  belongs_to :cor, class_name: 'Core', foreign_key: 'cod_cor', optional: true
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'cod_empresa'
  has_many :fotos, class_name: 'ItemOrcamentoFoto', foreign_key: 'cod_item',
           dependent: :destroy, inverse_of: :item_orcamento

  validates :quantidade, :valorunitario, presence: true
  validates :quantidade, numericality: { greater_than: 0 }

  def foto_principal
    fotos.order(:posicao_ordem).first
  end

  def valor_total
    subtotal = (valorunitario || 0) * (quantidade || 0)
    acrescimo = valor_acrescimo || 0
    desconto = valor_desconto || 0
    subtotal + acrescimo - desconto
  end

  def nome_produto
    produto&.nome
  end

  def estoque_disponivel
    Empresaproduto.where(cod_produto: cod_produto, cod_cor: cod_cor, cod_empresa: cod_empresa).pluck(:quantidade).first || 0
  end

  def full_codigo
    [self.cod_produto, self.cod_cor].join('-')
  end

end
