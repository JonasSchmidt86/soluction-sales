class ApplicationController < ActionController::Base

    before_action :set_global_params

    def set_global_params
        # a  $  significa que é global que pode ser acessada oelo model view ou controler
        $global_params = params
    end
end
