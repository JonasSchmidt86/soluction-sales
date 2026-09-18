class CollaboratorsBackoffice::CollaboratorsController < CollaboratorsBackofficeController
  
  before_action :verify_password, only: [:update]
  
  before_action :set_collaborator, only: [:edit, :update, :destroy]

  def index
    @collaborators = Collaborator.includes(:empresa).all.page(params[:page])
  end

  def reset_password
    @collaborator = Collaborator.find(params[:id])

    unless @collaborator.funcionario.ativo?
      return redirect_to collaborators_backoffice_collaborators_path,
                         alert: "Não é possível enviar e-mail para colaborador inativo."
    end

    token = @collaborator.send(:set_reset_password_token)

    begin
      CollaboratorMailer.set_password_email(@collaborator, token).deliver_now
      redirect_to collaborators_backoffice_collaborators_path,
                  notice: "E-mail de redefinição de senha enviado para #{@collaborator.email}."
    rescue => e
      # O token foi gerado, mas o envio falhou (ex.: SMTP indisponível).
      # Não deixamos a falha de e-mail derrubar a requisição com erro 500.
      Rails.logger.error("[reset_password] Falha ao enviar e-mail para #{@collaborator.email}: #{e.class} - #{e.message}")
      redirect_to collaborators_backoffice_collaborators_path,
                  alert: "Não foi possível enviar o e-mail agora. Tente novamente em instantes."
    end
  end

  def edit
  end
  
  def new
    @collaborator = Collaborator.new
    @collaborator.funcionario = Funcionario.new

  end

  def create
    # Remove senha dos parâmetros se estiver vazia
    if params[:collaborator][:password].blank?
      params[:collaborator].delete(:password)
      params[:collaborator].delete(:password_confirmation)
    end
    
    @collaborator = Collaborator.new(params_collaborator)
    unless @collaborator.save
      return redirect_to collaborators_backoffice_collaborators_path, alert: "Erro ao cadastrar Colaborador!"
    end

    # Colaborador salvo. O envio de e-mail é secundário: se falhar, não
    # desfazemos o cadastro nem retornamos erro 500.
    unless @collaborator.funcionario.ativo?
      return redirect_to collaborators_backoffice_collaborators_path,
                         alert: "Colaborador cadastrado, mas está inativo — e-mail não enviado."
    end

    token = @collaborator.send(:set_reset_password_token)

    begin
      CollaboratorMailer.set_password_email(@collaborator, token).deliver_now
      redirect_to collaborators_backoffice_collaborators_path, notice: "Colaborador cadastrado! E-mail enviado para #{@collaborator.email}"
    rescue => e
      Rails.logger.error("[create collaborator] Falha ao enviar e-mail para #{@collaborator.email}: #{e.class} - #{e.message}")
      redirect_to collaborators_backoffice_collaborators_path,
                  alert: "Colaborador cadastrado, mas não foi possível enviar o e-mail. Use 'Resetar Senha' para reenviar."
    end
  end

  def update
    puts "UPDATE #{params_collaborator}" 
    if @collaborator.update(params_collaborator)
      # Só faz login automático se for o próprio usuário logado editando
      if current_collaborator == @collaborator
        bypass_sign_in(@collaborator) # quando troca a senha não precisa refazer o login
      end

      if params_collaborator[:cod_empresa]
        redirect_to collaborators_backoffice_welcome_index_path, notice: "Você trocou de empresa!"
      else
        redirect_to collaborators_backoffice_welcome_index_path, notice: "Colaborador atualizado com sucesso!"
      end
      
    else 
      redirect_to collaborators_backoffice_welcome_index_path, alert: "ERRO"
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
