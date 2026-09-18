module Collaborators
  # Sobrescreve o PasswordsController do Devise apenas para controlar o destino
  # após o colaborador definir/redefinir a senha. O Devise já faz login
  # automático após o reset, então redirecionamos direto para a área interna.
  class PasswordsController < Devise::PasswordsController
    # Fluxo "esqueci minha senha": o Devise gera o token e envia o e-mail com
    # as instruções. Se o envio falhar (SMTP indisponível, limite atingido etc.),
    # não deixamos a requisição estourar com erro 500 — mostramos uma mensagem
    # amigável. O token já foi gerado, então um novo pedido pode ser feito depois.
    def create
      super
    rescue => e
      Rails.logger.error("[collaborators/passwords#create] Falha no envio do e-mail de recuperação: #{e.class} - #{e.message}")
      flash[:alert] = "Não foi possível enviar o e-mail agora. Tente novamente em instantes ou contate o administrador."
      redirect_to new_collaborator_session_path
    end

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
