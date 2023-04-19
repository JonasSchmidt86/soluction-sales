class CollaboratorsBackofficeController < ApplicationController

    before_action :authenticate_collaborator!
    layout 'collaborators_backoffice'

end
