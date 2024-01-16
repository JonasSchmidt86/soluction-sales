class CollaboratorsBackoffice::LembretesController < CollaboratorsBackofficeController
    
    before_action :set_lembrete, only: [:edit, :update, :destroy]
    before_action :get_empresas, only: [:new, :edit, :update,]

    def index
        if !params[:term].blank?
            @lembretes = Lembrete.where(" upper(descricao) ilike ? ", "#{params[:term].upcase}%" )
                                 .order(:datacadastro).page(params[:page])
        else
            @lembretes = Lembrete.where(ativo: true).order(:datacadastro).page(params[:page])
        end
    end

    def update
        if @lembrete.update!(params_lembrete)
            redirect_to collaborators_backoffice_lembretes_path, notice: "Lembrete atualizado com sucesso!"
        else 
            render :edit
        end
            
    end

    def edit
    end

    def new
        @lembrete = Lembrete.new
    end

    def create
        @lembrete = Lembrete.new(params_lembrete)
        @lembrete.cod_empresa = current_collaborator.cod_empresa
        @lembrete.cod_funcionario = current_collaborator.cod_funcionario
        @lembrete.datacadastro = DateTime.now
        @lembrete.ativo = true
        if @lembrete.save
            redirect_to collaborators_backoffice_lembretes_path, notice: "Lembrete Cadastrado com sucesso!"
        else 
            render :new
        end
    end

    def destroy
        @lembrete.ativo = false
        if @lembrete.save
        # render :index, notice: "Lembrete removido da Lista!"
        # if @lembrete.destroy
            redirect_to collaborators_backoffice_lembretes_path, notice: "Lembrete excluido com sucesso!"
        # else 
        #     render :index
        end
    end

    private 

    def params_lembrete
        params.require(:lembrete).permit(:descricao, :datacadastro, :cod_empresasolicitada )
    end

    def set_lembrete
        @lembrete = Lembrete.find(params[:id])
    end

    def get_empresas
        @empresas = Empresa.where("ativo = ? ", true).order(:cod_empresa)
    end 
end
