class Itemvenda < ApplicationRecord


    self.table_name = "itemvenda"
    self.primary_key = "cod_item"

    belongs_to :cor, :class_name => 'Core', :foreign_key => 'cod_cor' #, inverse_of: :cores
    
    belongs_to :venda, :class_name => 'Venda', :foreign_key => 'cod_venda', inverse_of: :itensvenda

    belongs_to :produto, :class_name => 'Produto', :foreign_key => 'cod_produto',
               inverse_of: :itensvenda
               
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa'#, inverse_of: :
    belongs_to :venda, :class_name => 'Venda', :foreign_key => 'cod_venda'#, inverse_of: :
    
    paginates_per 20
    
    def nome_produto
        if !self.produto.nil?
            self.produto.nome
        end
    end
    
    def valor_total
        (self.valorunitario || 0) * (self.quantidade || 0)
    end

    def full_codigo
        [self.cod_produto, self.cod_cor].join('-')
    end

    def valorunitario_o
        self.valorunitario
    end
end
