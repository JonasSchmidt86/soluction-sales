class CollaboratorsBackoffice::Report::RepEstoqueFiscalController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  # Relatorio de Estoque Fiscal: mostra o estoque fiscal CONSOLIDADO por PRODUTO
  # (fiscal_produto.qtd_fiscal) da EMPRESA LOGADA — a MESMA fonte que a emissao
  # da nota avulsa consulta para validar saldo fiscal. Filtros opcionais por:
  #   - nome ou codigo do produto (params[:term])
  #   - marca (params[:cod_marca])
  #   - grupo (params[:cod_grupo])
  # Paginacao no mesmo estilo do empresa_estoque: select de per_page iniciando
  # em 30, com opcao "Todas", e paginacao via Kaminari.
  #
  # Custo/valor de venda vivem em empresaproduto (por cor). Como aqui o estoque e
  # consolidado por produto, pegamos valores representativos por produto via uma
  # subquery (ultimo custo e maior valor de venda entre as cores da empresa).
  def index
    cod_empresa = current_collaborator.cod_empresa

    # Base: fiscal_produto (estoque fiscal consolidado por produto), ja escopado
    # na empresa logada, com o produto para nome/marca/grupo.
    query = FiscalProduto.includes(produto: [:parametro, :cod_grupo, :cod_marca])
                         .joins(:produto)
                         .where(fiscal_produto: { cod_empresa: cod_empresa })
                         .order("produto.nome ASC")

    # Filtro por marca
    if params[:cod_marca].present?
      query = query.where(produto: { marca: params[:cod_marca] })
    end

    # Filtro por grupo
    if params[:cod_grupo].present?
      query = query.where(produto: { grupo: params[:cod_grupo] })
    end

    # Filtro por nome ou codigo do produto
    if params[:term].present?
      term = params[:term].strip
      query = query.where(
        "produto.cod_produto::varchar = REPLACE(TRIM(?), '%', '') OR produto.nome ILIKE ?",
        term, "#{term}%"
      )
    end

    # Filtro "C/ Estoque": MARCADO por padrao. Quando marcado, traz todos com
    # estoque fiscal DIFERENTE de zero (inclui NEGATIVOS). Quando desmarcado,
    # traz os "sem estoque" (qtd_fiscal < 1): zeros e negativos.
    #
    # Default marcado: so considera desmarcado quando o form foi submetido
    # (params[:filtrou] presente) E o checkbox nao veio. Assim, ao abrir a tela
    # a 1a vez (sem submit), o padrao e "com estoque".
    com_estoque = com_estoque_fiscal_marcado?
    if com_estoque
      query = query.where("fiscal_produto.qtd_fiscal <> 0")
    else
      query = query.where("fiscal_produto.qtd_fiscal < 1")
    end
    @com_estoque_fiscal = com_estoque

    # Paginacao (igual empresa_estoque): per_page inicia em 30; "Todas" lista tudo.
    if params[:per_page] == 'Todas'
      @fiscal_produtos = query
    else
      per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : 30
      @fiscal_produtos = query.page(params[:page]).per(per_page)
    end

    # Custo (ultimo custo) e valor de venda (maior entre as cores) por produto,
    # a partir de empresaproduto da empresa logada — para as colunas da tabela.
    cods = @fiscal_produtos.map(&:cod_produto)
    @valores_por_produto = valores_empresaproduto(cod_empresa, cods)

    @marcas = Marca.all
    @grupos = Grupo.all
  end

  private

  # "C/ Estoque" vem MARCADO por padrao. So fica desmarcado quando o usuario
  # submeteu o form (params[:filtrou] = "1", hidden no form) e NAO marcou o
  # checkbox. No 1o acesso (sem submit) retorna true (marcado).
  def com_estoque_fiscal_marcado?
    return true unless params[:filtrou] == '1'
    params[:com_estoque_fiscal] == '1'
  end

  # Retorna { cod_produto => { custo:, valorvenda: } } com o ultimo custo e o
  # maior valor de venda entre as cores do produto na empresa. Uma unica query.
  def valores_empresaproduto(cod_empresa, cods_produto)
    return {} if cods_produto.blank?

    rows = Empresaproduto
           .where(cod_empresa: cod_empresa, cod_produto: cods_produto)
           .group(:cod_produto)
           .pluck(:cod_produto, "MAX(ultimocusto)", "MAX(valorvenda)")

    rows.each_with_object({}) do |(cod, custo, venda), h|
      h[cod] = { custo: custo.to_d, valorvenda: venda.to_d }
    end
  end

  # Mesma trava do menu fiscal: so acessa quem tem o modulo fiscal na empresa
  # logada e pode ver a config (super_admin). Protege a URL direta, ja que o
  # link do menu so aparece sob essa condicao.
  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.can_view?("fiscal_estoque")
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
