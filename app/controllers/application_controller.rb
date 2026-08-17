class ApplicationController < ActionController::Base
    
    # protect_from_forgery with: :exception
  
    before_action :set_locale
    before_action :set_pg_current_user
   
    skip_before_action :verify_authenticity_token, only: [:consulta_estoque]

    def set_locale
       locale = params[:locale] || cookies[:locale]
       if locale.present?
         I18n.locale = locale
         cookies[:locale] = { value: locale, expires: 30.days.from_now}
       end
     end

     # Seta o cod_funcionario logado na sessão do PostgreSQL
     # para que triggers possam saber quem está operando
     def set_pg_current_user
       if defined?(current_collaborator) && current_collaborator.present?
         ActiveRecord::Base.connection.execute(
           "SET LOCAL app.current_funcionario = '#{current_collaborator.cod_funcionario}'"
         )
       end
     rescue => e
       # Silencia erros para não quebrar a aplicação
       Rails.logger.debug "set_pg_current_user: #{e.message}"
     end

     # teste apenas
     before_action :set_global_params

     def set_global_params
         # a  $  significa que é global que pode ser acessada oelo model view ou controler
         $global_params = params
     end

  end