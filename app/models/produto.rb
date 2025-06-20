class Produto < ApplicationRecord
    self.table_name = "produto"
    self.primary_key = "cod_produto"
  
    # Corrigindo alias de atributos
    alias_attribute :cod_grupo, :grupo
    alias_attribute :cod_marca, :marca
  
    # Associações corretas
    belongs_to :cod_grupo, foreign_key: 'grupo', primary_key: 'cod_grupo', class_name: 'Grupo' #, optional: true
    belongs_to :cod_marca, foreign_key: 'marca', primary_key: 'cod_marca', class_name: 'Marca' #, optional: true
    belongs_to :parametro, foreign_key: 'cod_margem', class_name: 'Parametro', optional: true
  
    has_many :produto_imagens, class_name: 'ProdutoImagem', foreign_key: 'cod_produto', dependent: :destroy, autosave: true, inverse_of: :produto
    # accepts_nested_attributes_for :produto_imagens, allow_destroy: true, reject_if: :all_blank
  
    has_many :empresaprodutos, class_name: 'Empresaproduto', foreign_key: 'cod_produto', inverse_of: :produto
    has_many :itensvenda, class_name: 'Itemvenda', foreign_key: 'cod_produto', inverse_of: :produto
    has_many :itenscompra, class_name: 'Itemcompra', foreign_key: 'cod_produto', inverse_of: :produto
  
    # Validações
    validates :cod_produto, presence: true, uniqueness: true
    validates :nome, presence: true
    validates :ncm, presence: true
    validates :cest, presence: true
    validates :cfop, presence: true
    validates :ucom, presence: true
  
    # Scopes
    scope :ativos, -> { where(ativo: true) }
    scope :inativos, -> { where(ativo: false) }
  
    # Métodos de busca
    def self.search(query)
      where("cod_produto LIKE ? OR nome LIKE ?", "%#{query}%", "%#{query}%")
    end
  
    def cod_nome
      "#{nome} - #{cod_produto}"
    end
  
    def to_s
      nome
    end
  
    paginates_per 30
  end