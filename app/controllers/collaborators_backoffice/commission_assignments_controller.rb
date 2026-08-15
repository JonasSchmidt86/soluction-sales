class CollaboratorsBackoffice::CommissionAssignmentsController < CollaboratorsBackofficeController
  before_action :authorize_admin!
  before_action :set_commission_assignment, only: [:destroy]

  def index
    @assignments = CommissionAssignment.where(cod_empresa: current_empresa_id)
                                        .includes(:commission_rule)
                                        .order(start_date: :desc)

    if params[:cod_funcionario].present?
      @assignments = @assignments.where(cod_funcionario: params[:cod_funcionario])
    end

    @funcionarios = funcionarios_da_empresa
    @commission_rules = CommissionRule.for_empresa(current_empresa_id).active
  end

  def new
    @assignment = CommissionAssignment.new(
      cod_empresa: current_empresa_id,
      start_date: Date.today
    )
    @funcionarios = funcionarios_da_empresa
    @commission_rules = CommissionRule.for_empresa(current_empresa_id).active
  end

  def create
    @assignment = CommissionAssignment.new(assignment_params)
    @assignment.cod_empresa = current_empresa_id
    @assignment.created_by = current_collaborator.cod_funcionario

    # Fechar atribuição anterior se existir
    ActiveRecord::Base.transaction do
      previous = CommissionAssignment
        .where(cod_funcionario: @assignment.cod_funcionario, cod_empresa: current_empresa_id, end_date: nil)
        .where("start_date < ?", @assignment.start_date)
        .order(start_date: :desc)
        .first

      if previous
        previous.update!(end_date: @assignment.start_date - 1.day)
      end

      if @assignment.save
        redirect_to collaborators_backoffice_commission_assignments_path,
                    notice: 'Atribuição de regra criada com sucesso!'
      else
        @funcionarios = funcionarios_da_empresa
        @commission_rules = CommissionRule.for_empresa(current_empresa_id).active
        render :new, status: :unprocessable_entity
      end
    end
  end

  def destroy
    # Verificar se há apurações vinculadas a esta atribuição
    has_periods = CommissionPeriod
      .where(cod_funcionario: @assignment.cod_funcionario, cod_empresa: @assignment.cod_empresa)
      .where("start_date >= ?", @assignment.start_date)
      .where("end_date <= ?", @assignment.end_date || Date.new(9999, 12, 31))
      .exists?

    if params[:force_delete] == 'true' || !has_periods
      # Deletar de fato — sem apurações vinculadas ou exclusão forçada
      @assignment.destroy
      redirect_to collaborators_backoffice_commission_assignments_path,
                  notice: 'Atribuição excluída com sucesso!'
    elsif @assignment.end_date.nil?
      # Encerrar normalmente (comportamento anterior)
      @assignment.update!(end_date: Date.today)
      redirect_to collaborators_backoffice_commission_assignments_path,
                  notice: 'Atribuição encerrada com sucesso!'
    else
      redirect_to collaborators_backoffice_commission_assignments_path,
                  alert: 'Esta atribuição já foi encerrada.'
    end
  end

  private

  def set_commission_assignment
    @assignment = CommissionAssignment.where(cod_empresa: current_empresa_id).find(params[:id])
  end

  def assignment_params
    params.require(:commission_assignment).permit(:commission_rule_id, :cod_funcionario, :start_date)
  end

  def authorize_admin!
    unless admin?
      redirect_to collaborators_backoffice_welcome_index_path,
                  alert: 'Acesso negado. Apenas administradores podem gerenciar atribuições de comissão.'
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
               .where(ativo: true)
               .includes(:pessoa)
               .order(:usuario)
  end
end
