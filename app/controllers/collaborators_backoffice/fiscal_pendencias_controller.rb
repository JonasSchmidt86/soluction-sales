class CollaboratorsBackoffice::FiscalPendenciasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  def index
    # Produtos ativos com alguma pendencia fiscal que impede emissao.
    base = Produto.where(ativo: true)

    @sem_ncm    = base.where("ncm IS NULL OR ncm = '' OR ncm = '00000000'")
    @sem_perfil = base.where(cod_perfil_tributario: nil)
    @sem_origem = base.where("origem IS NULL OR origem = ''")

    # Contagens (para os cards do topo)
    @qtd_sem_ncm    = @sem_ncm.count
    @qtd_sem_perfil = @sem_perfil.count
    @qtd_sem_origem = @sem_origem.count

    # Lista combinada paginada, com o(s) motivo(s) de cada produto.
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

  def autorizar_fiscal!
    unless access_control.can_view?("fiscal_pendencias")
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
