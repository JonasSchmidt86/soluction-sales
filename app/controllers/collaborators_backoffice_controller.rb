class CollaboratorsBackofficeController < ApplicationController

    before_action :authenticate_collaborator!
    #before_action :verificar_horario_comercial
    layout 'collaborators_backoffice'

    def check_cpf_cnpj
        cpf_cnpj = params[:cpf_cnpj].gsub(/\D/, '')  # Remove todos os caracteres não numéricos
        pessoa = Pessoa.find_by(cpf_cnpj: cpf_cnpj)
        
        # Verifica se uma pessoa foi encontrada
        if pessoa
          puts pessoa
          render json: pessoa
        else
          render json: { status: 'not_found' }
        end
  
      end

    private

    def verificar_horario_comercial
        return unless current_collaborator&.empresa&.controlar_horario?
        
        unless current_collaborator.empresa.horario_comercial?
            sign_out current_collaborator
            # redirect_to collaborators_backoffice_collaborators_path(alert: "Acesso negado fora do horário comercial!")
            redirect_to new_collaborator_session_path(alert: "Acesso negado fora do horário comercial!")
        end
    end

end
