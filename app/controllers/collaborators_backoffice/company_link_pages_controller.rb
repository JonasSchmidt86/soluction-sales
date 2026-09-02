class CollaboratorsBackoffice::CompanyLinkPagesController < CollaboratorsBackofficeController
  before_action :require_admin!
  before_action :set_company_link_page, only: [:edit, :update, :destroy]

  def index
    @company_link_pages = CompanyLinkPage.includes(:empresa).order(:empresa_id)
  end

  def new
    @company_link_page = CompanyLinkPage.new
    @company_link_page.social_links.build
  end

  def create
    @company_link_page = CompanyLinkPage.new(company_link_page_params)

    if @company_link_page.save
      anexar_imagem
      atualizar_contatos_publicados
      redirect_to collaborators_backoffice_company_link_pages_path,
                  notice: "Página de links criada com sucesso."
    else
      @company_link_page.social_links.build if @company_link_page.social_links.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @company_link_page.social_links.build if @company_link_page.social_links.empty?
  end

  def update
    if @company_link_page.update(company_link_page_params)
      anexar_imagem
      atualizar_contatos_publicados
      redirect_to collaborators_backoffice_company_link_pages_path,
                  notice: "Página de links atualizada."
    else
      @company_link_page.social_links.build if @company_link_page.social_links.empty?
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company_link_page.destroy
    redirect_to collaborators_backoffice_company_link_pages_path,
                notice: "Página de links removida."
  end

  private

  # Restringe o acesso a administradores (permissao.nivel == 1)
  def require_admin!
    return if access_control.admin?

    redirect_to collaborators_backoffice_welcome_index_path,
                alert: "Acesso negado. Apenas administradores podem gerenciar as páginas de links."
  end

  def set_company_link_page
    @company_link_page = CompanyLinkPage.find(params[:id])
  end

  # Anexa a imagem. Prioriza o recorte feito no navegador (Cropper.js, base64).
  # Se não houver recorte, usa o arquivo enviado com recorte automático no centro.
  def anexar_imagem
    recorte = params.dig(:company_link_page, :imagem_recortada)
    if recorte.present?
      @company_link_page.attach_imagem_from_data_url(recorte)
      return
    end

    imagem = params.dig(:company_link_page, :imagem)
    @company_link_page.resize_imagem_before_attach(imagem) if imagem.present?
  end

  # Marca quais contatos de WhatsApp da empresa aparecem na página pública
  def atualizar_contatos_publicados
    ids_publicados = Array(params[:whatsapp_contact_ids]).map(&:to_i)
    contatos = WhatsappContact.where(empresa_id: @company_link_page.empresa_id)
    contatos.each do |contato|
      contato.update_column(:publicar_link, ids_publicados.include?(contato.id))
    end
  end

  def company_link_page_params
    params.require(:company_link_page).permit(
      :empresa_id, :slug, :titulo, :descricao, :publicado, :formato_imagem, :imagem_recortada,
      :cor_fundo_inicio, :cor_fundo_fim, :cor_texto,
      social_links_attributes: [:id, :tipo, :titulo, :url, :ordem, :ativo, :_destroy]
    )
  end
end
