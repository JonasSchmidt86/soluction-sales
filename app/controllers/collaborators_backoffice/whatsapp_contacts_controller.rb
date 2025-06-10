class CollaboratorsBackoffice::WhatsappContactsController < CollaboratorsBackofficeController
    # before_action :authenticate_collaborator!
  before_action :set_whatsapp_contact, only: [:edit, :update, :destroy]

  def index
    @whatsapp_contacts = if params[:term].present?
      WhatsappContact.includes(:empresa, :funcionario).where("display_name ILIKE ?", "%#{params[:term]}%")
    else
      WhatsappContact.includes(:empresa, :funcionario).all
    end 
    @whatsapp_contacts = @whatsapp_contacts.order(created_at: :desc).page(params[:page])
  end

  def show
    # Lógica para exibir ou processar o conteúdo do arquivo XML
  end

  def new
    @whatsapp_contact = WhatsappContact.new
  end

  def create
    @whatsapp_contact = WhatsappContact.new(whatsapp_contact_params)
  
    if whatsapp_contact_params[:photo]
      @whatsapp_contact.resize_photo_before_attach(whatsapp_contact_params[:photo])
    end

    if @whatsapp_contact.save
      redirect_to collaborators_backoffice_whatsapp_contacts_path, notice: 'Contato criado com sucesso.'
    else
      render :new
    end
  end

  def edit; end

  def update
    if whatsapp_contact_params[:photo]
      @whatsapp_contact.resize_photo_before_attach(whatsapp_contact_params[:photo])
    end
    
    if @whatsapp_contact.update(whatsapp_contact_params)
      redirect_to collaborators_backoffice_whatsapp_contacts_path, notice: 'Contato atualizado.'
    else
      render :edit
    end
  end

  def destroy
    @whatsapp_contact.destroy
    redirect_to collaborators_backoffice_whatsapp_contacts_path, notice: 'Contato removido.'
  end

  private


  def set_whatsapp_contact
    @whatsapp_contact = WhatsappContact.find(params[:id])
  end

  def whatsapp_contact_params
    params.require(:whatsapp_contact).permit(:empresa_id, :funcionario_id, :display_name, :whatsapp_number, :email, :photo)
  end

end
