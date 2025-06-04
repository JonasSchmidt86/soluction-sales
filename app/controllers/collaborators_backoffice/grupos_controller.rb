module CollaboratorsBackoffice
  class GruposController < CollaboratorsBackofficeController

    before_action :set_grupo, only: [:edit, :update, :destroy]

    def index
      
      if params[:term].present?
        @grupos = Grupo.where("cod_grupo::text ILIKE ? OR nomegrupo ILIKE ?", "%#{params[:term]}%", "%#{params[:term]}%")
      else 
        @grupos = Grupo.all
      end
      @grupos = @grupos.order(:cod_grupo).page(params[:page]).per(30)
    end

    def new
      @grupo = Grupo.new
    end

    def edit; end

    def create
      @grupo = Grupo.new(grupo_params)
      if @grupo.save
        redirect_to collaborators_backoffice_grupos_path, notice: 'Grupo cadastrado com sucesso.'
      else
        render :new
      end
    end

    def update
      if @grupo.update(grupo_params)
        redirect_to collaborators_backoffice_grupos_path, notice: 'Grupo atualizado com sucesso.'
      else
        render :edit
      end
    end

    def destroy
      if pode_excluir?(@grupo)
        @grupo.destroy
        redirect_to collaborators_backoffice_grupos_path, notice: 'Grupo excluído com sucesso.'
      else
        redirect_to collaborators_backoffice_grupos_path, alert: 'Não é possível excluir. Existem produtos vinculados.'
      end
    end

    private

    def set_grupo
      @grupo = Grupo.find_by(cod_grupo: params[:cod_grupo])
    end

    def grupo_params
      params.require(:grupo).permit(:nome, :ativo)
    end

    def pode_excluir?(grupo)
      Produto.where(grupo: grupo.cod_grupo).none?
    end
  end
end
