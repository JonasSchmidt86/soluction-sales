class CollaboratorsBackoffice::CollaboratorsController < CollaboratorsBackofficeController
  
  before_action :verify_password, only: [:update]
  before_action :set_collaborator, only: [:edit, :update, :destroy]
  
  def index
    @collaborators = Collaborator.all.page(params[:page])
  end

  def edit
  end
  
  def new
    @collaborator = Collaborator.new
    @collaborator.funcionario = Funcionario.new

  end

  def create
    @collaborator = Collaborator.new(params_collaborator)
    if @collaborator.save
      redirect_to collaborators_backoffice_collaborators_path, notice: "Colaborador Cadastrado com sucesso!"
    else 
      render :new
    end
  end

  def update
    if @collaborator.update(params_collaborator)
      bypass_sign_in(@collaborator) # quando troca a senha não precisa refazer o login

      if params_collaborator[:cod_empresa]
        redirect_to collaborators_backoffice_welcome_index_path, notice: "Você trocou de empresa!"
      else
        redirect_to collaborators_backoffice_welcome_index_path, notice: "Colaborador atualizado com sucesso!"
      end
      
    else 
      redirect_to collaborators_backoffice_welcome_index_path, notice: "ERRO"
    end

  end

  def destroy
    if @collaborator.destroy
      redirect_to collaborators_backoffice_collaborators_path, notice: "Colaborador excluido com sucesso!"
    else 
      render :index
    end
  end

private

def params_collaborator
  params.require(:collaborator).permit(:email, :password, :password_confirmation, :cod_empresa, :cod_funcionario )
end

def set_collaborator 
  @collaborator = Collaborator.find(params[:id])
end

def verify_password
  if params[:collaborator][:password].blank? && params[:collaborator][:password_confirmation].blank?
    params[:collaborator].extract!(:password, :password_confirmation)
  end
end

end
