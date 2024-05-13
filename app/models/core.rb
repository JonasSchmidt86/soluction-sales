class Core < ApplicationRecord

    self.table_name = "cores"
    self.primary_key = 'cod_cor'

    has_many :empresaprodutos, :class_name => 'Empresaproduto', :foreign_key => 'cod_cor', inverse_of: :cor

    def nmcor_cod
        return [self.nmcor, self.cod_cor].join(' - ')
    end
    
    def to_s
        nmcor;
    end
end
