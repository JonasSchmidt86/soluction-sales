module Collaborators
  # Sobrescreve o PasswordsController do Devise apenas para controlar o destino
  # após o colaborador definir/redefinir a senha. O Devise já faz login
  # automático após o reset, então redirecionamos direto para a área interna.
  class PasswordsController < Devise::PasswordsController
    protected

    # Para onde ir depois de redefinir a senha com sucesso.
    # O Devise já faz login automático, então mandamos direto para o dashboard.
    def after_resetting_password_path_for(resource)
      if signed_in?(resource_name)
        collaborators_backoffice_welcome_index_path
      else
        new_session_path(resource_name)
      end
    end
  end
end
