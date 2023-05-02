class CollaboratorsBackoffice::FuncionariosController < CollaboratorsBackofficeController
    
    before_action :set_funcionario, only: [:edit, :update, :destroy]
    # before_action :params_funcionario, only: [:edit, :update, :destroy]

    def index
        if !params[:term].blank?
            @funcionarios = Funcionario.where(" upper(usuario) like ? and cod_funcionario in 
                                ( select cod_funcionario from funcionarioempresa where cod_empresa = ? )", 
                                "#{params[:term].upcase}%", current_collaborator.cod_empresa )
                                 .order(:datacontrato).page(params[:page])
        else
            @funcionarios = Funcionario.where("cod_funcionario in 
                                ( select cod_funcionario from funcionarioempresa where cod_empresa = ?) and ativo = ? ", current_collaborator.cod_empresa, true).
                                order(:datacontrato).page(params[:page])
        end
    end

    def update
        if @funcionario.update( params_funcionario )
            # bypass_sign_in(@funcionario.collaborator) # quando troca a senha não precisa refazer o login
            if !params_funcionario[:avatar]
                redirect_to collaborators_backoffice_funcionarios_path, notice: "Usuario atualizado com sucesso!"
            else
                redirect_to collaborators_backoffice_welcome_index_path, notice: "Foto Atualizada!!"
            end
        else 
            render :edit
        end
    end

    def edit
    end

    def new
        @funcionario = Funcionario.new
    end

    def create

        @funcionario = Funcionario.new(params_funcionario)

        for i in @funcionario.funcionariosempresa do
            i.funcionario = @funcionario
            puts @funcionario.funcionariosempresa
        end 

        if @funcionario.save
            redirect_to collaborators_backoffice_funcionarios_path, notice: "Colaborador Cadastrado com sucesso!"
        else 
            render :new
        end
    end

    def destroy
        @funcionario.ativo = false
        if @funcionario.save
            redirect_to collaborators_backoffice_funcionarios_path, notice: "Colaborador removido com sucesso!"
         end
    end

    private 

    def params_funcionario
        params.require(:funcionario).permit(:ativo, :datacontrato, :datademissao, :salario,
                                            :usuario, :cod_permissao, :cod_pessoa, :avatar,
                                            funcionariosempresa_attributes: [:cod_empresa, :cod_funcionario, :_destroy],
                                            collaborator_attributes: [:email, :password, :password_confirmation, :cod_empresa, :_destroy] )
      end

    def set_funcionario
        @funcionario = Funcionario.find(params[:id])
    end
end
