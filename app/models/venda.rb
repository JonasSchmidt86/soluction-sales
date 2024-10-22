class Venda < ApplicationRecord

    self.table_name = "venda"
    self.primary_key = "cod_venda"

    #https://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html
    has_many :itensvenda, :class_name => 'Itemvenda', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :delete_all, autosave: true
    accepts_nested_attributes_for :itensvenda, allow_destroy: true, update_only: true #, reject_if: :all_blank

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :delete_all, autosave: true
    accepts_nested_attributes_for :contas, allow_destroy: true, update_only: true #, reject_if: :all_blank

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :vendas
    accepts_nested_attributes_for :pessoa, allow_destroy: false

    belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :vendas
    
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :vendas

    validates :itensvenda, :contas, :funcionario, :empresa, :pessoa, presence: true

    paginates_per 30

    def nome_pessoa
        if !pessoa.nil?
            return pessoa.nome
        end
    end
    def self.pessoa 
        unless self.pessoa.blank?
            return self.pessoa.nome
        end
    end

    def venda_nfe
        if self.cancelada
            return ["CANCELADA", (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
        else
            return [self.cod_vendaempresa, (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
        end
    end

    def valorRecebido
        valor = 0
        unless self.cancelada
            for conta in self.contas do
                unless conta.lancamentos.blank?
                    for launch in conta.lancamentos do
                        valor += launch.valor
                    end
                end
            end
        end
        return valor
    end
    
    def valorDevido
        return self.valortotal - self.valorRecebido
    end
    
    def valorCusto
        valorCusto = 0;
        for item in self.itensvenda do 
            valorCusto += ((item.valororiginal || 0) * (item.quantidade || 0))
        end
        return valorCusto;
    end
    
end
