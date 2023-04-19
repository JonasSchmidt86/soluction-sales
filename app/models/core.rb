class Core < ApplicationRecord

    self.table_name = "cores"
    self.primary_key = 'cod_cor'

    has_many :empresaprodutos, :class_name => 'Empresaproduto', :foreign_key => 'cod_cor', inverse_of: :cor

    
end
