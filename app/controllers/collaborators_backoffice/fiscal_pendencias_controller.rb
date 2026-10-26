class CollaboratorsBackoffice::FiscalPendenciasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  def index
    cod_empresa = current_collaborator.cod_empresa

    # Produtos ativos com alguma pendencia fiscal que impede emissao. As
    # pendencias sao avaliadas pelo fiscal da EMPRESA (fiscal_produto) com
    # fallback no produto global via COALESCE: usa o valor da fiscal_produto
    # quando existe, senao o do produto. Assim a lista reflete o que cada
    # empresa tem (Etapa 5 do fiscal_produto).
    base = Produto.where(ativo: true)
      .joins(Produto.sanitize_sql_array([
        "LEFT JOIN fiscal_produto fp ON fp.cod_produto = produto.cod_produto AND fp.cod_empresa = ?",
        cod_empresa
      ]))

    # Filtro de estoque (padrao: so com estoque FISCAL na empresa logada).
    # Emissao usa empresaproduto.qtdfiscal (nao a quantidade fisica).
    # Alinhado ao padrao do sistema: exige empresaproduto.ativo E cores.ativo.
    # ?estoque=todos -> traz todos; ausente/qualquer -> so com qtdfiscal > 0.
    @estoque = params[:estoque].presence || "com"
    if @estoque != "todos"
      com_estoque_ids = Empresaproduto
        .joins(:cor)
        .where(cod_empresa: cod_empresa, ativo: true)
        .where(cores: { ativo: true })
        .where("empresaproduto.qtdfiscal > 0")
        .distinct
        .pluck(:cod_produto)
      base = base.where(cod_produto: com_estoque_ids)
    end

    # COALESCE(fiscal_produto, produto): a fiscal_produto manda; fallback global.
    ncm_expr    = "COALESCE(NULLIF(fp.ncm, ''), produto.ncm)"
    perfil_expr = "COALESCE(fp.cod_perfil_tributario, produto.cod_perfil_tributario)"
    origem_expr = "COALESCE(NULLIF(fp.origem, ''), produto.origem)"

    @sem_ncm    = base.where("#{ncm_expr} IS NULL OR #{ncm_expr} = '' OR #{ncm_expr} = '00000000'")
    @sem_perfil = base.where("#{perfil_expr} IS NULL")
    @sem_origem = base.where("#{origem_expr} IS NULL OR #{origem_expr} = ''")

    @qtd_sem_ncm    = @sem_ncm.count
    @qtd_sem_perfil = @sem_perfil.count
    @qtd_sem_origem = @sem_origem.count

    ids = (@sem_ncm.pluck(:cod_produto) + @sem_perfil.pluck(:cod_produto) + @sem_origem.pluck(:cod_produto)).uniq

    filtro = params[:filtro]
    escopo =
      case filtro
      when "ncm"    then @sem_ncm
      when "perfil" then @sem_perfil
      when "origem" then @sem_origem
      else Produto.where(cod_produto: ids)
      end

    @filtro = filtro
    @produtos = escopo.order(:nome).page(params[:page])
    @total_pendentes = ids.size
  end

  private

  # Acesso liberado apenas se a EMPRESA logada tem modulo fiscal (FiscalConfig ativo).
  # Garante que so opera o fiscal quem esta logado na empresa que o tem.
  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.can_view?("fiscal_pendencias")
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
