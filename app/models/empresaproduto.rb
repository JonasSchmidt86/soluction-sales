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

    def estoq_real
      sql = <<~SQL
        SELECT function_estoquereal(
          :cod_empresa::integer,
          :cod_produto::integer,
          :cod_cor::integer
        )
      SQL

      binds = {
        cod_empresa: cod_empresa,
        cod_produto: cod_produto,
        cod_cor:     cod_cor
      }

      self.class.connection
        .select_value(self.class.send(:sanitize_sql_array, [sql, binds]))
        .to_i
    end

  paginates_per 20
    
end
