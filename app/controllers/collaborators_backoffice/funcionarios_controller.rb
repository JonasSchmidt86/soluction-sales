class CollaboratorsBackoffice::FuncionariosController < CollaboratorsBackofficeController
    
    before_action :set_funcionario, only: [:edit, :update, :destroy]
    # before_action :params_funcionario, only: [:edit, :update, :destroy]

    def index
        if !params[:term].blank?
            @funcionarios = Funcionario.where(" upper(usuario) ilike ? and ativo = true ", 
                                "#{params[:term].upcase}%" )
                                 .order(:datacontrato).page(params[:page])
        else
            @funcionarios = Funcionario.where(" ativo = ? ", true).
                                order(:datacontrato).page(params[:page])
        end
    end

    def update
        if params[:funcionario] && !params_funcionario[:avatar]

            @funcionario.ativo = params[:funcionario][:ativo]
            @funcionario.datacontrato = params[:funcionario][:datacontrato]
            @funcionario.salario = params[:funcionario][:salario]
            @funcionario.cod_permissao = params[:funcionario][:cod_permissao]
            @funcionario.usuario = params[:funcionario][:usuario]

            if params[:funcionario][:funcionarioempresas_attributes]
                params[:funcionario][:funcionarioempresas_attributes].each do |index, empresa_attributes|
                    codigo = empresa_attributes[:cod_empresa]
                    empresa = Empresa.find_by(cod_empresa: codigo)

                    funcionario_empresa = @funcionario.funcionarioempresas.find_or_initialize_by(empresa: empresa)

                    if funcionario_empresa.new_record? && funcionario_empresa.attributes.slice(*empresa_attributes.keys).all? { |_, v| v.blank? }
                        # Remover funcionario_empresa da coleção
                        @funcionario.funcionarioempresas.delete(funcionario_empresa)
                        next  # Pular para a próxima iteração sem salvar ou processar mais nada para este funcionario_empresa
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
                    else
                        puts empresa_attributes[:ativo]
                        funcionario_empresa.ativo = empresa_attributes[:ativo].to_i == 1
                        if funcionario_empresa.cod_funcionarioempresa.blank?
                            funcionario_empresa.ativo = true
                        end    
                        funcionario_empresa.save!
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

        @funcionario = Funcionario.new
        #@funcionario.funcionariosempresa.build

        if params[:funcionario][:funcionarioempresas_attributes]
            params[:funcionario][:funcionarioempresas_attributes].each do |index, empresa_attributes|
                codigo = empresa_attributes[:cod_empresa]
                empresa = Empresa.find_by(cod_empresa: codigo)

                funcionario_empresa = @funcionario.funcionarioempresas.find_or_initialize_by(empresa: empresa)
                funcionario_empresa.ativo = true
                @funcionario.funcionarioempresas << funcionario_empresa;
            end
        end

        pessoa = Pessoa.find_by(cod_pessoa: params[:funcionario][:cod_pessoa])
        
        if pessoa
            @funcionario.pessoa = pessoa;
            @funcionario.cod_permissao = params[:funcionario][:cod_permissao]
            @funcionario.datacontrato = params[:funcionario][:datacontrato]
            @funcionario.datademissao = params[:funcionario][:datademissao]
            @funcionario.salario = params[:funcionario][:salario]
            @funcionario.ativo = !!params[:funcionario][:ativo]
            @funcionario.usuario = params[:funcionario][:usuario]

            if @funcionario.save
                redirect_to collaborators_backoffice_funcionarios_path, notice: "Colaborador Cadastrado com sucesso!"
            else 
                render :new
            end
        else
            puts "ERRO"
            render :new, notice: "Informe uma pessoa!"
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
        return params.require(:funcionario).permit(:pessoa_nome, :cod_funcionario, :ativo, :datacontrato, :datademissao, :salario,
                                            :usuario, :cod_permissao, :cod_pessoa, :avatar,
                                            funcionarioempresas_attributes: [:id, :cod_funcionarioempresa, :cod_empresa, :cod_funcionario, :ativo, :_destroy],
                                            collaborator_attributes: [:email, :password, :password_confirmation, :cod_empresa, :_destroy] )

      end

    def set_funcionario
        @funcionario = Funcionario.find(params[:id])
    end
end
