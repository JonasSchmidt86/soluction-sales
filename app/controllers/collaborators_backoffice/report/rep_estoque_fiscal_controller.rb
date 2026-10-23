class CollaboratorsBackoffice::Report::RepEstoqueFiscalController < CollaboratorsBackofficeController

  # Relatorio de Estoque Fiscal: mostra a quantidade fiscal (empresaproduto.qtdfiscal)
  # por produto/cor da EMPRESA LOGADA, com filtros opcionais por:
  #   - nome ou codigo do produto (params[:term])
  #   - marca (params[:cod_marca])
  #   - grupo (params[:cod_grupo])
  # Paginacao no mesmo estilo do empresa_estoque: select de per_page iniciando
  # em 30, com opcao "Todas", e paginacao via Kaminari.
  def index
    # Consulta base: estoque fiscal da empresa logada, produtos ativos.
    query = Empresaproduto.includes(:cor, produto: [:parametro, :cod_grupo, :cod_marca])
                          .joins(:produto)
                          .where(empresaproduto: { cod_empresa: current_collaborator.cod_empresa, ativo: true })
                          .order("produto.nome ASC, empresaproduto.cod_cor ASC")

    # Filtro por marca
    if params[:cod_marca].present?
      query = query.where(produto: { cod_marca: params[:cod_marca] })
    end

    # Filtro por grupo
    if params[:cod_grupo].present?
      query = query.where(produto: { cod_grupo: params[:cod_grupo] })
    end

    # Filtro por nome ou codigo do produto
    if params[:term].present?
      term = params[:term].strip
      query = query.where(
        "produto.cod_produto::varchar = REPLACE(TRIM(?), '%', '') OR produto.nome ILIKE ?",
        term, "#{term}%"
      )
    end

    # Filtro: trazer apenas produtos COM estoque fiscal (qtdfiscal > 0).
    if params[:com_estoque_fiscal] == '1'
      query = query.where("empresaproduto.qtdfiscal > 0")
    end

    # Paginacao (igual empresa_estoque): per_page inicia em 30; "Todas" lista tudo.
    if params[:per_page] == 'Todas'
      @empresa_produtos = query
    else
      per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : 30
      @empresa_produtos = query.page(params[:page]).per(per_page)
    end

    @marcas = Marca.all
    @grupos = Grupo.all
  end
end
