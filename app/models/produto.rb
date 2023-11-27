class Produto < ApplicationRecord

    self.table_name = "produto"
    self.primary_key = "cod_produto"
    
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


    def cod_nome
        return [self.nome, self.cod_produto].join(' - ');
    end

    paginates_per 10
    
end
