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

    def registro_scpc( parametros )
        puts "------------------>>>>ESSE Paramentro ---->> " + parametros.to_s
        if parametros.nil?
            "Não consultado" 
        else
            if parametros.to_s == "false"
                "Sem Registro"
            else
                "Com Registro"
            end
        end
    end
end
