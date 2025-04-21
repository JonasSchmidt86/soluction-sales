class CollaboratorsBackofficeController < ApplicationController

    before_action :authenticate_collaborator!
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

end
