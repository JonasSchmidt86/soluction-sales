class CollaboratorsBackoffice::PerfisTributariosController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_perfil, only: [:show, :edit, :update, :destroy]

  def index
    @perfis = PerfilTributario.order(:nome)
  end

  def show
  end

  def new
    @perfil = PerfilTributario.new(ativo: true)
  end

  def create
    @perfil = PerfilTributario.new(perfil_params)
    if @perfil.save
      redirect_to edit_collaborators_backoffice_perfil_tributario_path(@perfil),
                  notice: "Perfil criado. Agora adicione as regras fiscais."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @perfil.update(perfil_params)
      redirect_to collaborators_backoffice_perfil_tributario_path(@perfil),
                  notice: "Perfil tributário atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @perfil.produtos.exists?
      redirect_to collaborators_backoffice_perfis_tributarios_path,
                  alert: "Não é possível excluir: há produtos usando este perfil."
    else
      @perfil.destroy
      redirect_to collaborators_backoffice_perfis_tributarios_path,
                  notice: "Perfil tributário excluído."
    end
  end

  private

  def set_perfil
    @perfil = PerfilTributario.find(params[:id])
  end

  def perfil_params
    params.require(:perfil_tributario).permit(:nome, :descricao, :ativo)
  end

  def current_empresa_id
    current_collaborator.cod_empresa
  end

  # Acesso liberado apenas se a EMPRESA logada tem modulo fiscal (FiscalConfig ativo).
  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal?
      redirect_to collaborators_backoffice_welcome_index_path,
                  alert: "Acesso negado."
    end
  end
end
