class Empresaproduto < ApplicationRecord


    self.table_name = "empresaproduto"
    self.primary_key = "id"


    belongs_to :cor, :class_name => 'Core', :foreign_key => 'cod_cor', inverse_of: :empresaprodutos

    belongs_to :produto, :class_name => 'Produto', :foreign_key => 'cod_produto', 
            inverse_of: :empresaprodutos
            
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa'#, inverse_of: :parametros
    
      # atributo virtual
    def full_codigo
      [self.cod_produto, self.cod_cor].join('-')
    end

  paginates_per 20
    
end
