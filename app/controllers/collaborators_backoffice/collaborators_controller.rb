class CollaboratorsBackoffice::CollaboratorsController < CollaboratorsBackofficeController
  
  before_action :verify_password, only: [:update]
  
  before_action :set_collaborator, only: [:edit, :update, :destroy]

  def index
    @collaborators = Collaborator.includes(:empresa).all.page(params[:page])
  end

  def reset_password
    @collaborator = Collaborator.find(params[:id])
    token = @collaborator.send(:set_reset_password_token) # Chama o método protegido de forma segura

    CollaboratorMailer.set_password_email(@collaborator, token).deliver_now

    redirect_to collaborators_backoffice_collaborators_path, 
                notice: "E-mail de redefinição de senha enviado para #{@collaborator.email}."
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
      @collaborator.send_reset_password_instructions # Envia o e-mail com link para definir senha
      redirect_to collaborators_backoffice_collaborators_path, notice: "Colaborador Cadastrado com sucesso!"
    else 
      redirect_to collaborators_backoffice_collaborators_path, notice: "Erro ao cadastrar Colaborador!"
    end
  end

  def update
    puts "UPDATE #{params_collaborator}" 
    if @collaborator.update(params_collaborator)
      bypass_sign_in(@collaborator) # quando troca a senha não precisa refazer o login

      if params_collaborator[:cod_empresa]
        redirect_to root_path, notice: "Você trocou de empresa!"
      else
        redirect_to root_path, notice: "Colaborador atualizado com sucesso!"
      end
      
    else 
      redirect_to root_path, notice: "ERRO"
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
