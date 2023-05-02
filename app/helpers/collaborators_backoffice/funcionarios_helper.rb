module CollaboratorsBackoffice::FuncionariosHelper
    
    def ativo_select(current_ativo)
        current_collaborator.funcionario.ativo == current_ativo ? 'btn-primary' : 'btn-default'
    end

end
