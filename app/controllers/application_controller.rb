class ApplicationController < ActionController::Base
    
    # protect_from_forgery with: :exception
  
    before_action :set_locale
   
    skip_before_action :verify_authenticity_token, only: [:consulta_estoque]

    def set_locale
       locale = params[:locale] || cookies[:locale]
       if locale.present?
         I18n.locale = locale
         cookies[:locale] = { value: locale, expires: 30.days.from_now}
       end
     end


     # teste apenas
     before_action :set_global_params

     def set_global_params
         # a  $  significa que é global que pode ser acessada oelo model view ou controler
         $global_params = params
     end

  end