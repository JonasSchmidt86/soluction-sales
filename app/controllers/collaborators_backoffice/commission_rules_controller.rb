class CollaboratorsBackoffice::CommissionRulesController < CollaboratorsBackofficeController
  before_action :authorize_admin!
  before_action :set_commission_rule, only: [:show, :edit, :update, :destroy]

  def index
    @commission_rules = CommissionRule.for_empresa(current_empresa_id)
                                      .includes(:commission_tiers)
                                      .order(:name)
  end

  def show
    @assignments = @commission_rule.commission_assignments
                                    .order(start_date: :desc)
  end

  def new
    @commission_rule = CommissionRule.new(cod_empresa: current_empresa_id)
    @commission_rule.commission_tiers.build(position: 1, min_value: 0)
  end

  def create
    @commission_rule = CommissionRule.new(commission_rule_params)
    @commission_rule.cod_empresa = current_empresa_id

    if @commission_rule.save
      redirect_to collaborators_backoffice_commission_rule_path(@commission_rule),
                  notice: 'Regra de comissão criada com sucesso!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @commission_rule.update(commission_rule_params)
      redirect_to collaborators_backoffice_commission_rule_path(@commission_rule),
                  notice: 'Regra de comissão atualizada com sucesso!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @commission_rule.commission_assignments.exists?
      redirect_to collaborators_backoffice_commission_rules_path,
                  alert: 'Não é possível excluir uma regra que está atribuída a vendedores.'
    else
      @commission_rule.destroy
      redirect_to collaborators_backoffice_commission_rules_path,
                  notice: 'Regra de comissão excluída com sucesso!'
    end
  end

  private

  def set_commission_rule
    @commission_rule = CommissionRule.for_empresa(current_empresa_id).find(params[:id])
  end

  def commission_rule_params
    params.require(:commission_rule).permit(
      :name, :description, :active,
      commission_tiers_attributes: [:id, :position, :min_value, :max_value, :percentage, :_destroy]
    )
  end

  def authorize_admin!
    unless admin?
      redirect_to collaborators_backoffice_welcome_index_path,
                  alert: 'Acesso negado. Apenas administradores podem gerenciar regras de comissão.'
    end
  end

  def admin?
    current_collaborator.funcionario.permissao&.nivel == 1
  end

  def current_empresa_id
    current_collaborator.cod_empresa
  end
end
