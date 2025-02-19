class Itemcompra < ApplicationRecord

    self.table_name = "itemcompra"
    self.primary_key = "cod_item"
    
    attr_accessor :pro_xml_temp #list

    paginates_per 10

    belongs_to :cor, :class_name => 'Core', :foreign_key => 'cod_cor' #, inverse_of: :cores
    belongs_to :produto, :class_name => 'Produto', :foreign_key => 'cod_produto', inverse_of: :itenscompra
               
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa'#, inverse_of: :
    belongs_to :compra, :class_name => 'Compra', :foreign_key => 'cod_compra', inverse_of: :itenscompra

    def nome_produto
        if !self.produto.nil?
            self.produto.nome
        end
    end
    
    def valor_total
        (self.valorunitario * self.quantidade) + self.ipi + self.valorst + self.valor_frete
    end

    def full_codigo
        [self.cod_produto, self.cod_cor].join('-')
    end

    def valorunitario_o
        self.valorunitario
    end

end