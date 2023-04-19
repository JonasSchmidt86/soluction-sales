class CollaboratorsBackoffice::WelcomeController < CollaboratorsBackofficeController

    before_action :get_empresas, only: [:index]

    def index
    end

    private

    def get_empresas
        
        # puts current_collaborator.cod_funcionario
        # @empresas = Empresa.where("cod_empresa in (select cod_empresa from funcionarioempresa where cod_funcionario = ?  )", current_collaborator.cod_funcionario).order(:cod_empresa)
        # @empresaLog = @empresa
    end
end