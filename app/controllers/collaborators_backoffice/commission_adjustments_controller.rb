class CollaboratorsBackoffice::CommissionAdjustmentsController < CollaboratorsBackofficeController
  before_action :authorize_admin!
  before_action :set_adjustment, only: [:show, :cancel]

  def index
    @adjustments = CommissionAdjustment.where(cod_empresa: current_empresa_id)
                                        .order(created_at: :desc)

    if params[:cod_funcionario].present?
      @adjustments = @adjustments.where(cod_funcionario: params[:cod_funcionario])
    end

    if params[:status].present?
      @adjustments = @adjustments.where(status: params[:status])
    end

    @adjustments = @adjustments.page(params[:page]).per(20)
    @funcionarios = funcionarios_da_empresa
  end

  def show
  end

  def new
    @adjustment = CommissionAdjustment.new(
      cod_empresa: current_empresa_id,
      direction: 'debit'
    )
    @funcionarios = funcionarios_da_empresa
  end

  def create
    result = CommissionAdjustmentService.create_manual(
      cod_funcionario: params[:commission_adjustment][:cod_funcionario],
      cod_empresa: current_empresa_id,
      amount: params[:commission_adjustment][:amount],
      direction: params[:commission_adjustment][:direction],
      reason: params[:commission_adjustment][:reason],
      created_by: current_collaborator.cod_funcionario,
      cod_venda: params[:commission_adjustment][:cod_venda].presence,
      commission_period_id: params[:commission_adjustment][:commission_period_id].presence
    )

    redirect_to collaborators_backoffice_commission_adjustments_path,
                notice: "Ajuste criado com sucesso! Valor: R$ #{result.amount}"
  rescue ActiveRecord::RecordInvalid => e
    @adjustment = CommissionAdjustment.new(
      cod_empresa: current_empresa_id,
      cod_funcionario: params[:commission_adjustment][:cod_funcionario],
      amount: params[:commission_adjustment][:amount],
      direction: params[:commission_adjustment][:direction],
      reason: params[:commission_adjustment][:reason]
    )
    @funcionarios = funcionarios_da_empresa
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def cancel
    CommissionAdjustmentService.cancel(@adjustment, cancelled_by: current_collaborator.cod_funcionario)
    redirect_to collaborators_backoffice_commission_adjustments_path,
                notice: 'Ajuste cancelado com sucesso!'
  rescue CommissionAdjustmentService::Error => e
    redirect_to collaborators_backoffice_commission_adjustments_path, alert: e.message
  end

  # Detecta vendas canceladas e cria ajustes automáticos
  def detect_cancelled
    results = CommissionAdjustmentService.detect_cancelled_sales_for_empresa(
      cod_empresa: current_empresa_id
    )

    total_created = results.values.flatten.count

    if total_created > 0
      redirect_to collaborators_backoffice_commission_adjustments_path,
                  notice: "#{total_created} ajuste(s) criado(s) automaticamente para vendas canceladas."
    else
      redirect_to collaborators_backoffice_commission_adjustments_path,
                  notice: 'Nenhuma venda cancelada pendente de ajuste encontrada.'
    end
  end

  private

  def set_adjustment
    @adjustment = CommissionAdjustment.where(cod_empresa: current_empresa_id).find(params[:id])
  end

  def authorize_admin!
    unless admin?
      redirect_to collaborators_backoffice_welcome_index_path,
                  alert: 'Acesso negado. Apenas administradores podem gerenciar ajustes de comissão.'
    end
  end

  def admin?
    current_collaborator.funcionario.permissao&.nivel == 1
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
