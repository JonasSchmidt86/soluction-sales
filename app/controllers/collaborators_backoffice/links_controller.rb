
class CollaboratorsBackoffice::LinksController < CollaboratorsBackofficeController
  def index
    @links = Link.where(active: true).order(:position)
  end
end
