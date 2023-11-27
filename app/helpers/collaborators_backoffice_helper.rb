module CollaboratorsBackofficeHelper

    def avatar_url
        avatar = current_collaborator.funcionario.avatar
        avatar.attached? ? avatar : 'img.jpg'
    end

    def get_operacao
        @test = ["Entrada", 2], ["Saida", 3], ["Canceladas", 4]
    end

    def get_cores(id_produto)
        unless id_produto.nil?
            cores = Core.select(:nmcor, :cod_cor).joins(:empresaprodutos).where("cod_produto = ? and cod_empresa = ?", id_produto, current_collaborator.cod_empresa );
            return cores
        end
    end

end
