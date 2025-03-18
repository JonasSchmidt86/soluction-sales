class Produto < ApplicationRecord

    self.table_name = "produto"
    self.primary_key = "cod_produto"
    
    has_many_attached :imagens, service: :produtos_storage
    
    self.alias_attribute :cod_grupo, :grupo # cod_grupo referece a tabela produto e esta errado na tab produto apenas grupo
    self.alias_attribute :cod_marca, :marca

    has_one :cod_marca, :class_name => 'Marca', :foreign_key => 'cod_marca' #, optional: true #, inverse_of: :marcas
    has_one :cod_grupo, :class_name => 'Grupo', :foreign_key => 'cod_grupo' #, optional: true  #, inverse_of: :grupos
    
    belongs_to :parametro, :class_name => 'Parametro', :foreign_key => 'cod_margem', optional: true #, inverse_of: :parametros
    
    
    has_many :empresaprodutos, :class_name => 'Empresaproduto', :foreign_key => 'cod_produto', 
             inverse_of: :produto

    has_many :itensvenda, :class_name => 'Itemvenda', :foreign_key => 'cod_produto', 
             inverse_of: :produto

    has_many :itenscompra, :class_name => 'Itemcompra', :foreign_key => 'cod_produto', 
             inverse_of: :produto

    has_many :produto_imagens, :class_name =>'ProdutoImagem', :foreign_key => 'id',  dependent: :destroy
    accepts_nested_attributes_for :produto_imagens, allow_destroy: true, reject_if: :all_blank

    belongs_to :grupo, foreign_key: 'cod_grupo', primary_key: 'cod_grupo', class_name: 'Grupo'
    belongs_to :marca, foreign_key: 'cod_marca', primary_key: 'cod_marca', class_name: 'Marca'
    
    validates :cod_produto, presence: true, uniqueness: true
    validates :nome, presence: true
    validates :ncm, presence: true
    validates :cest, presence: true
    validates :cfop, presence: true
    validates :ucom, presence: true
    
    scope :ativos, -> { where(ativo: true) }
    scope :inativos, -> { where(ativo: false) }
    
    def self.search(query)
      where("cod_produto LIKE ? OR nome LIKE ?", "%#{query}%", "%#{query}%")
    end

    def cod_nome
        return [self.nome, self.cod_produto].join(' - ');
    end

    def to_s
        nome;
    end

    paginates_per 30
    
end
