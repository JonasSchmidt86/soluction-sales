class CollaboratorsBackoffice::AccessRolesController < CollaboratorsBackofficeController
  before_action :authorize_admin!
  before_action :set_access_role, only: [:show, :edit, :update, :destroy, :assign, :unassign, :add_permission, :remove_permission]

  def index
    @access_roles = AccessRole.for_empresa(current_empresa_id).includes(:access_role_permissions, :collaborator_access_roles).order(:name)
  end

  def show
    @permissions = @access_role.access_role_permissions.order(:resource)
    @assigned = @access_role.collaborator_access_roles
    @available_resources = AccessRolePermission::AVAILABLE_RESOURCES
    @funcionarios = funcionarios_da_empresa
  end

  def new
    @access_role = AccessRole.new(cod_empresa: current_empresa_id)
    @available_resources = AccessRolePermission::AVAILABLE_RESOURCES
  end

  def create
    @access_role = AccessRole.new(access_role_params)
    @access_role.cod_empresa = current_empresa_id

    if @access_role.save
      # Criar permissões selecionadas
      save_permissions_from_params
      redirect_to collaborators_backoffice_access_role_path(@access_role),
                  notice: 'Perfil de acesso criado com sucesso!'
    else
      @available_resources = AccessRolePermission::AVAILABLE_RESOURCES
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @permissions = @access_role.access_role_permissions.order(:resource)
    @available_resources = AccessRolePermission::AVAILABLE_RESOURCES
  end

  def update
    if @access_role.update(access_role_params)
      # Recriar permissões
      @access_role.access_role_permissions.destroy_all
      save_permissions_from_params
      redirect_to collaborators_backoffice_access_role_path(@access_role),
                  notice: 'Perfil atualizado com sucesso!'
    else
      @permissions = @access_role.access_role_permissions.order(:resource)
      @available_resources = AccessRolePermission::AVAILABLE_RESOURCES
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @access_role.collaborator_access_roles.exists?
      redirect_to collaborators_backoffice_access_roles_path,
                  alert: 'Não é possível excluir um perfil que está atribuído a colaboradores.'
    else
      @access_role.destroy
      redirect_to collaborators_backoffice_access_roles_path,
                  notice: 'Perfil excluído com sucesso!'
    end
  end

  # Atribuir perfil a um colaborador
  def assign
    cod_funcionario = params[:cod_funcionario].to_i

    # Remover atribuição anterior se existir
    CollaboratorAccessRole.where(cod_funcionario: cod_funcionario, cod_empresa: current_empresa_id).destroy_all

    CollaboratorAccessRole.create!(
      access_role: @access_role,
      cod_funcionario: cod_funcionario,
      cod_empresa: current_empresa_id
    )

    redirect_to collaborators_backoffice_access_role_path(@access_role),
                notice: 'Colaborador atribuído ao perfil com sucesso!'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to collaborators_backoffice_access_role_path(@access_role), alert: e.message
  end

  # Remover atribuição
  def unassign
    assignment = CollaboratorAccessRole.find_by(id: params[:assignment_id], cod_empresa: current_empresa_id)
    if assignment
      assignment.destroy
      redirect_to collaborators_backoffice_access_role_path(@access_role),
                  notice: 'Atribuição removida com sucesso!'
    else
      redirect_to collaborators_backoffice_access_role_path(@access_role), alert: 'Atribuição não encontrada.'
    end
  end

  # Gerenciamento de permissões individuais (overrides)
  def individual_permissions
    @funcionarios = funcionarios_da_empresa
    @permissions = CollaboratorPermission.where(cod_empresa: current_empresa_id).order(:cod_funcionario, :resource)

    if params[:cod_funcionario].present?
      @permissions = @permissions.where(cod_funcionario: params[:cod_funcionario])
    end

    @available_resources = AccessRolePermission::AVAILABLE_RESOURCES
  end

  def create_individual_permission
    perm = CollaboratorPermission.new(
      cod_funcionario: params[:collaborator_permission][:cod_funcionario],
      cod_empresa: current_empresa_id,
      resource: params[:collaborator_permission][:resource],
      can_view: params[:collaborator_permission][:can_view] == '1',
      can_create: params[:collaborator_permission][:can_create] == '1',
      can_edit: params[:collaborator_permission][:can_edit] == '1',
      can_delete: params[:collaborator_permission][:can_delete] == '1'
    )

    if perm.save
      redirect_to individual_permissions_collaborators_backoffice_access_roles_path,
                  notice: 'Permissão individual criada com sucesso!'
    else
      redirect_to individual_permissions_collaborators_backoffice_access_roles_path,
                  alert: "Erro: #{perm.errors.full_messages.join(', ')}"
    end
  end

  def destroy_individual_permission
    perm = CollaboratorPermission.where(cod_empresa: current_empresa_id).find_by(id: params[:permission_id])
    if perm
      perm.destroy
      redirect_to individual_permissions_collaborators_backoffice_access_roles_path,
                  notice: 'Permissão individual removida!'
    else
      redirect_to individual_permissions_collaborators_backoffice_access_roles_path,
                  alert: 'Permissão não encontrada.'
    end
  end

  private

  def set_access_role
    @access_role = AccessRole.for_empresa(current_empresa_id).find(params[:id])
  end

  def access_role_params
    params.require(:access_role).permit(:name, :description, :active)
  end

  def save_permissions_from_params
    return unless params[:permissions].present?

    params[:permissions].each do |resource, actions|
      # Só cria se pelo menos uma ação está marcada
      can_view = actions[:can_view] == '1'
      can_create = actions[:can_create] == '1'
      can_edit = actions[:can_edit] == '1'
      can_delete = actions[:can_delete] == '1'

      if can_view || can_create || can_edit || can_delete
        @access_role.access_role_permissions.create!(
          resource: resource,
          can_view: can_view,
          can_create: can_create,
          can_edit: can_edit,
          can_delete: can_delete
        )
      end
    end
  end

  def authorize_admin!
    unless current_collaborator.funcionario.permissao&.nivel == 1
      redirect_to collaborators_backoffice_welcome_index_path,
                  alert: 'Acesso negado. Apenas administradores podem gerenciar perfis de acesso.'
    end
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
