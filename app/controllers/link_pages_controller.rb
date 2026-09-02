class LinkPagesController < ApplicationController
  # Página pública "link na bio" (estilo Linktree). Sem autenticação.
  def show
    @link_page = CompanyLinkPage.publicadas.find_by!(slug: params[:slug])
    @whatsapp_contacts = @link_page.whatsapp_contacts
    @social_links = @link_page.social_links.ativos
    render layout: false
  rescue ActiveRecord::RecordNotFound
    render plain: "Página não encontrada", status: :not_found
  end
end
