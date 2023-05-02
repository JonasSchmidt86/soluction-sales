class Pessoa < ApplicationRecord

    self.table_name = "pessoa"
    self.primary_key = "cod_pessoa"
    
    has_many :vendas, :class_name => 'Venda', :foreign_key => 'cod_pessoa'
    has_many :compras, :class_name => 'Compra', :foreign_key => 'cod_pessoa'
    has_many :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_pessoa'
    has_many :fretes, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :pessoa
    # has_one :funcionario, :inverse_of :pessoa
            
    has_many :lancamentos, :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :pessoa

end
