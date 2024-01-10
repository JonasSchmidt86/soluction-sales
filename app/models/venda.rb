class Venda < ApplicationRecord

    self.table_name = "venda"
    self.primary_key = "cod_venda"

    #https://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html
    has_many :itensvenda, :class_name => 'Itemvenda', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :delete_all
    accepts_nested_attributes_for :itensvenda, allow_destroy: true, update_only: true, reject_if: :all_blank

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :delete_all
    accepts_nested_attributes_for :contas, allow_destroy: true #, update_only: true, reject_if: :all_blank

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :vendas
    
    belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :vendas
    
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :vendas

    validates :itensvenda, :contas, :funcionario, :empresa, :contas, presence: true

    paginates_per 20

    def venda_nfe
        [self.cod_vendaempresa, self.numeronf].join(' / ')
    end
    
end
