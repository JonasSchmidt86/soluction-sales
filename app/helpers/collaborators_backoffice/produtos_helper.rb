module CollaboratorsBackoffice::ProdutosHelper

    def getBrands(name)

        Marca.where(" upper(nome) like upper( ? ) ", name).order(:nome)
        # current_collaborator.funcionario.ativo == current_ativo ? 'btn-primary' : 'btn-default'
    end

end
