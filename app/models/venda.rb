class Venda < ApplicationRecord

    self.table_name = "venda"
    self.primary_key = "cod_venda"

    has_many :itensvenda, :class_name => 'Itemvenda', :foreign_key => 'cod_venda', inverse_of: :venda
    accepts_nested_attributes_for :itensvenda, update_only: true, reject_if: :all_blank, allow_destroy: true

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_venda', inverse_of: :venda
    accepts_nested_attributes_for :contas, update_only: true, reject_if: :all_blank, allow_destroy: true

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :vendas
    
    belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :vendas
    
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :vendas


    paginates_per 20

end
