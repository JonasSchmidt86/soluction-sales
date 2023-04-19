module CollaboratorsBackofficeHelper

    def avatar_url
        avatar = current_collaborator.funcionario.avatar
        avatar.attached? ? avatar : 'img.jpg'
    end

    def get_operacao
        @test = ["Entrada", 2], ["Saida", 3], ["Canceladas", 4]
    end

end
