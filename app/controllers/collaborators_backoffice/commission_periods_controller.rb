class CollaboratorsBackoffice::CommissionPeriodsController < CollaboratorsBackofficeController
  before_action :authorize_access!
  before_action :authorize_admin!, except: [:index, :show]
  before_action :set_commission_period, only: [:show, :calculate, :finalize, :mark_as_paid, :reopen]

  def index
    @periods = base_scope.includes(:commission_rule).order(start_date: :desc)

    if params[:cod_funcionario].present?
      @periods = @periods.where(cod_funcionario: params[:cod_funcionario])
    end

    if params[:status].present?
      @periods = @periods.where(status: params[:status])
    end

    @periods = @periods.page(params[:page]).per(20)
    @funcionarios = funcionarios_da_empresa
  end

  def show
    @sales = @period.commission_period_sales.ordered
    @adjustments = CommissionAdjustment.where(commission_period_id: @period.id)
                                        .or(CommissionAdjustment.where(applied_in_period_id: @period.id))
    @pending_adjustments = CommissionAdjustment.pending
                                               .for_funcionario(@period.cod_funcionario)
                                               .for_empresa(@period.cod_empresa)
    @payments = @period.commission_payments.order(paid_at: :desc)
  end

  def new
    @period = CommissionPeriod.new(
      cod_empresa: current_empresa_id,
      start_date: Date.today.beginning_of_month,
      end_date: Date.today.end_of_month
    )
    @funcionarios = funcionarios_da_empresa
  end

  def create
    @period = CommissionPeriod.new(period_params)
    @period.cod_empresa = current_empresa_id

    if @period.save
      redirect_to collaborators_backoffice_commission_period_path(@period),
                  notice: 'Período de apuração criado com sucesso!'
    else
      @funcionarios = funcionarios_da_empresa
      render :new, status: :unprocessable_entity
    end
  end

  def calculate
    ensure_admin!
    service = CommissionPeriodService.new(@period)
    @result = service.calculate
    redirect_to collaborators_backoffice_commission_period_path(@period),
                notice: "Cálculo realizado! Comissão: R$ #{@period.net_commission}"
  rescue CommissionPeriodService::Error => e
    redirect_to collaborators_backoffice_commission_period_path(@period), alert: e.message
  end

  def finalize
    ensure_admin!
    service = CommissionPeriodService.new(@period)
    service.finalize(finalized_by: current_collaborator.cod_funcionario)
    redirect_to collaborators_backoffice_commission_period_path(@period),
                notice: 'Comissão finalizada com sucesso!'
  rescue CommissionPeriodService::Error => e
    redirect_to collaborators_backoffice_commission_period_path(@period), alert: e.message
  end

  def mark_as_paid
    ensure_admin!
    service = CommissionPeriodService.new(@period)
    service.mark_as_paid(paid_by: current_collaborator.cod_funcionario)
    redirect_to collaborators_backoffice_commission_period_path(@period),
                notice: 'Comissão marcada como paga!'
  rescue CommissionPeriodService::Error => e
    redirect_to collaborators_backoffice_commission_period_path(@period), alert: e.message
  end

  def reopen
    ensure_super_admin!
    reason = params[:reopen_reason]
    if reason.blank?
      redirect_to collaborators_backoffice_commission_period_path(@period),
                  alert: 'Motivo da reabertura é obrigatório.'
      return
    end

    service = CommissionPeriodService.new(@period)
    service.reopen(reopened_by: current_collaborator.cod_funcionario, reason: reason)
    redirect_to collaborators_backoffice_commission_period_path(@period),
                notice: 'Comissão reaberta com sucesso!'
  rescue CommissionPeriodService::Error => e
    redirect_to collaborators_backoffice_commission_period_path(@period), alert: e.message
  end

  private

  def set_commission_period
    @period = base_scope.find(params[:id])
  end

  def period_params
    params.require(:commission_period).permit(:cod_funcionario, :start_date, :end_date)
  end

  # Vendedor vê somente sua própria comissão; admin vê todas da empresa
  def base_scope
    if admin?
      CommissionPeriod.for_empresa(current_empresa_id)
    else
      CommissionPeriod.for_funcionario(current_collaborator.cod_funcionario)
                      .for_empresa(current_empresa_id)
    end
  end

  def authorize_access!
    # Todos os colaboradores autenticados da empresa podem acessar (mas filtrados)
    true
  end

  def authorize_admin!
    unless admin?
      redirect_to collaborators_backoffice_commission_periods_path,
                  alert: 'Acesso negado. Apenas administradores podem realizar esta operação.'
    end
  end

  def ensure_admin!
    unless admin?
      raise CommissionPeriodService::PermissionError, 'Permissão negada.'
    end
  end

  def ensure_super_admin!
    unless super_admin?
      redirect_to collaborators_backoffice_commission_period_path(@period),
                  alert: 'Apenas o administrador geral pode reabrir comissões.'
      return
    end
  end

  def admin?
    current_collaborator.funcionario.permissao&.nivel == 1
  end

  def super_admin?
    current_collaborator.funcionario.super_admin?
  end

  def current_empresa_id
    current_collaborator.cod_empresa
  end

  def funcionarios_da_empresa
    Funcionario.joins(:funcionarioempresas)
               .where(funcionarioempresa: { cod_empresa: current_empresa_id, ativo: true })
               .includes(:pessoa)
               .order(:usuario)
  end
end
