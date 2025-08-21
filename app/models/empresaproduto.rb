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
      sql = "SELECT function_estoquereal($1, $2, $3)"
      result = self.class.connection.select_value(
        self.class.send(:sanitize_sql_array, [sql, cod_empresa, cod_produto, cod_cor])
      )
      result.to_i


      # # ajuste :quantidade se o nome da coluna na view for outro (ex.: :qtd, :saldo, etc.)
      # EstoqueReal
      # .where(
      #     cod_empresa: cod_empresa,
      #     cod_produto: cod_produto,
      #     cod_cor:     cod_cor
      #   )
      #   .pick(:estoque_real) || 0
    end

  paginates_per 20
    
end
