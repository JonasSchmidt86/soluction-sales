class CollaboratorsBackoffice::WhatsappMessagesController < CollaboratorsBackofficeController
  before_action :require_admin!
  before_action :set_whatsapp_message, only: [:edit, :update, :destroy]

  def index
    @whatsapp_messages = WhatsappMessage
      .da_empresa(current_collaborator.cod_empresa)
      .order(:ordem, :id)
  end

  def new
    @whatsapp_message = WhatsappMessage.new(ativo: true)
  end

  def create
    @whatsapp_message = WhatsappMessage.new(whatsapp_message_params)
    @whatsapp_message.empresa_id = current_collaborator.cod_empresa

    if @whatsapp_message.save
      redirect_to collaborators_backoffice_whatsapp_messages_path,
                  notice: "Mensagem criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @whatsapp_message.update(whatsapp_message_params)
      redirect_to collaborators_backoffice_whatsapp_messages_path,
                  notice: "Mensagem atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @whatsapp_message.destroy
    redirect_to collaborators_backoffice_whatsapp_messages_path,
                notice: "Mensagem removida."
  end

  private

  # Restringe o acesso a administradores (permissao.nivel == 1)
  def require_admin!
    return if access_control.admin?

    redirect_to collaborators_backoffice_welcome_index_path,
                alert: "Acesso negado. Apenas administradores podem gerenciar as mensagens de WhatsApp."
  end

  # Garante que só registros da empresa logada sejam manipulados (multi-tenant).
  def set_whatsapp_message
    @whatsapp_message = WhatsappMessage
      .da_empresa(current_collaborator.cod_empresa)
      .find(params[:id])
  end

  def whatsapp_message_params
    params.require(:whatsapp_message).permit(:titulo, :mensagem, :categoria, :ativo, :ordem)
  end
end
