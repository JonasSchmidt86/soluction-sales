class Compra < ApplicationRecord

    self.table_name = "compra"
    self.primary_key = "cod_compra"

    has_many :itensCompra, :class_name => 'Itemcompra', :foreign_key => 'cod_item', inverse_of: :compra

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_venda', inverse_of: :compra

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :compras
    
    belongs_to :collaborator, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :compras
    
    belongs_to :frete, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :compra, dependent: :destroy

    
end
