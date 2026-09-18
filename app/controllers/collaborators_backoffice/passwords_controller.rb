module CollaboratorsBackoffice
  # Permite que o colaborador LOGADO troque a própria senha, informando a
  # senha atual. Complementa o fluxo por e-mail (usado por um admin para
  # redefinir a senha de outro colaborador).
  class PasswordsController < CollaboratorsBackofficeController
    def edit
      @collaborator = current_collaborator
    end

    def update
      @collaborator = current_collaborator

      unless @collaborator.valid_password?(params.dig(:collaborator, :current_password).to_s)
        @collaborator.errors.add(:current_password, "senha atual incorreta")
        return render :edit, status: :unprocessable_entity
      end

      if @collaborator.update(password_params)
        # Mantém a sessão ativa após a troca (Devise invalida a sessão por padrão).
        bypass_sign_in(@collaborator)
        redirect_to collaborators_backoffice_welcome_index_path,
                    notice: "Senha alterada com sucesso!"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.require(:collaborator).permit(:password, :password_confirmation)
    end
  end
end
