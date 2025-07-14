class CollaboratorsBackoffice::Report::RepStockMinController < CollaboratorsBackofficeController
  
  def index
    conditions = ["ep.cod_empresa = ?", current_collaborator.cod_empresa]
    
    # Filtro por marca
    if params[:cod_marca].present?
      conditions[0] += " AND p.marca = ?"
      conditions << params[:cod_marca]
    end
    
    # Filtro por grupo
    if params[:cod_grupo].present?
      conditions[0] += " AND p.grupo = ?"
      conditions << params[:cod_grupo]
    end
    
    # Filtro por nome ou código do produto
    if params[:search].present?
      conditions[0] += " AND (UPPER(p.nome) LIKE UPPER(?) OR CONCAT(p.cod_produto, '-', ep.cod_cor) LIKE ?)"
      conditions << "%#{params[:search]}%"
      conditions << "%#{params[:search]}%"
    end
    
    sql = <<~SQL
      SELECT 
        CONCAT(p.cod_produto, '-', ep.cod_cor) as codigo,
        p.nome,
        c.nmcor,
        ep.quantidademinima as estoque_minimo,
        ep.quantidade as estoque
      FROM empresaproduto as ep
        JOIN produto as p ON ep.cod_produto = p.cod_produto
        JOIN cores as c ON c.cod_cor = ep.cod_cor
      WHERE #{conditions[0]}
        AND ep.quantidade <= ep.quantidademinima
        AND ep.quantidademinima > 0
      ORDER BY p.nome
    SQL
    
    @stock_items = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql] + conditions[1..-1])
    )
    
    @marcas = Marca.all
    @grupos = Grupo.all
  end
end