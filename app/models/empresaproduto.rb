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

    # Valor de venda para EXIBICAO. Quando valorvenda ja esta cadastrado (> 0),
    # retorna ele. Quando esta zerado, calcula a partir do ultimo custo aplicando
    # a margem do produto (ou, na falta, a margem do grupo), replicando a mesma
    # formula da trigger tgrf_estoquecompra:
    #   valorvenda = custo * (1 + margem/100)   (margem = percentual)
    # Se nao houver margem, cai no proprio custo.
    def valor_venda_calculado
      return valorvenda if valorvenda.to_f > 0

      custo = ultimocusto.to_f
      return custo if custo <= 0

      margem = margem_aplicada
      margem > 0 ? (custo * (1 + margem / 100)).round(2) : custo
    end

    # Percentual de margem aplicavel ao produto: primeiro a margem do proprio
    # produto (parametros.margemproduto via cod_margem), depois a margem do grupo
    # como fallback. Considera apenas parametros ativos (igual a trigger).
    def margem_aplicada
      prod = produto
      return 0.0 if prod.nil?

      # Margem do proprio produto (usa a associacao :parametro = cod_margem).
      parametro = prod.parametro
      pct = (parametro&.ativo ? parametro.margemproduto.to_f : 0.0)
      return pct if pct > 0

      # Fallback: margem do grupo (usa a associacao :cod_grupo ja carregada).
      grupo_margem = prod.cod_grupo&.cod_margem
      return 0.0 if grupo_margem.blank?

      Parametro.where(ativo: true, cod_parametro: grupo_margem).pick(:margemproduto).to_f
    end

  paginates_per 20
    
end
