class CollaboratorsBackoffice::FiscalPendenciasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  def index
    # Produtos ativos com alguma pendencia fiscal que impede emissao.
    base = Produto.where(ativo: true)

    # Filtro de estoque (padrao: so com estoque FISCAL na empresa logada).
    # Emissao usa empresaproduto.qtdfiscal (nao a quantidade fisica).
    # Alinhado ao padrao do sistema: exige empresaproduto.ativo E cores.ativo.
    # ?estoque=todos -> traz todos; ausente/qualquer -> so com qtdfiscal > 0.
    @estoque = params[:estoque].presence || "com"
    if @estoque != "todos"
      com_estoque_ids = Empresaproduto
        .joins(:cor)
        .where(cod_empresa: current_collaborator.cod_empresa, ativo: true)
        .where(cores: { ativo: true })
        .where("empresaproduto.qtdfiscal > 0")
        .distinct
        .pluck(:cod_produto)
      base = base.where(cod_produto: com_estoque_ids)
    end

    @sem_ncm    = base.where("ncm IS NULL OR ncm = '' OR ncm = '00000000'")
    @sem_perfil = base.where(cod_perfil_tributario: nil)
    @sem_origem = base.where("origem IS NULL OR origem = ''")

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
    unless empresa_tem_modulo_fiscal?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
