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
        if params[:funcionario] && !params_funcionario[:avatar]

            @funcionario.ativo = params[:funcionario][:ativo]
            @funcionario.datacontrato = params[:funcionario][:datacontrato]
            @funcionario.salario = params[:funcionario][:salario]
            @funcionario.cod_permissao = params[:funcionario][:cod_permissao]

            if params[:funcionario][:funcionarioempresas_attributes]
                params[:funcionario][:funcionarioempresas_attributes].each do |index, empresa_attributes|
                    codigo = empresa_attributes[:cod_empresa]
                    empresa = Empresa.find_by(cod_empresa: codigo)

                    # Verificar se a empresa já existe na tabela funcionarioempresa
                    funcionario_empresa = @funcionario.funcionarioempresas.find_by(empresa: empresa)

                    if funcionario_empresa
                        #if funcionario_empresa.ativo != !!empresa_attributes[:ativo]
                        if  funcionario_empresa.ativo = empresa_attributes[:ativo].to_i != 0
                            funcionario_empresa.ativo = empresa_attributes[:ativo].to_i != 0
                            funcionario_empresa.save!
                        end

                        # A empresa já existe para este funcionário
                        if empresa_attributes[:_destroy] && ['true', '1'].include?(empresa_attributes[:_destroy].to_s)
                            # Tentar remover a associação e desativar o registro em caso de erro
                            begin
                                funcionario_empresa.destroy
                            rescue ActiveRecord::InvalidForeignKey => e
                                # Capturar a exceção e tratar conforme necessário
                                funcionario_empresa.update!(ativo: false)
                            end
                        end
                    else
                        # A empresa não existe, então podemos adicioná-la
                        @funcionario.empresas << empresa if empresa
                        #funcionario_empresa.ativo = true # Ativar a empresa
                    end
                end
            end
        end
        
        if params_funcionario[:avatar]
            
            if @funcionario.update!(params_funcionario)
                redirect_to collaborators_backoffice_welcome_index_path, notice: "Foto Atualizada!!"
            else 
                render redirect_to collaborators_backoffice_welcome_index_path, notice: "Atualização da foto falhou!!"
            end

        else
            if @funcionario.save!
                # bypass_sign_in(@funcionario.collaborator) # quando troca a senha não precisa refazer o login
                redirect_to collaborators_backoffice_funcionarios_path, notice: "Usuario atualizado com sucesso!"
            else 
                render :edit
            end
        end 

    end
      

    def edit
        #@funcionario.funcionariosempresa.build if @funcionario.funcionariosempresa.blank?
    end

    def new
        @funcionario = Funcionario.new
    end

    def create

        @funcionario = Funcionario.new(params_funcionario)
        @funcionario.funcionariosempresa.build

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

        puts "inicio erro ------------------- "
        return params.require(:funcionario).permit(:cod_funcionario, :ativo, :datacontrato, :datademissao, :salario,
                                            :usuario, :cod_permissao, :cod_pessoa, :avatar,
                                            funcionarioempresas_attributes: [:id, :cod_funcionarioempresa, :cod_empresa, :cod_funcionario, :ativo, :_destroy],
                                            collaborator_attributes: [:email, :password, :password_confirmation, :cod_empresa, :_destroy] )

      end

    def set_funcionario
        @funcionario = Funcionario.find(params[:id])
    end
end
