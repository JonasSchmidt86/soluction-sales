class CollaboratorsBackoffice::CoresController < CollaboratorsBackofficeController
  before_action :set_cor, only: %i[ show edit update destroy ]

  def index
    if params[:term].present?
      term = params[:term].strip
      @cores = Core.where(
        'cod_cor::varchar = REPLACE(TRIM(:query), \'%\', \'\') OR nmcor ILIKE :like_query',
        query: term,
        like_query: "%#{term}%"
      ).order(:cod_cor, :nmcor).page(params[:page])
    else
      @cores = Core.order(:nmcor).page(params[:page])
    end
  end

  def show
  end

  def new
    @cor = Core.new
  end

  def edit
  end

  def create
    @cor = Core.new(cor_params)

    if @cor.save
      redirect_to collaborators_backoffice_cores_path, notice: 'Cor criada com sucesso.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @cor.update(cor_params)
      redirect_to collaborators_backoffice_cores_path, notice: 'Cor atualizada com sucesso.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cor.destroy
    redirect_to collaborators_backoffice_cores_path, notice: 'Cor excluída com sucesso.'
  end

  private

    def set_cor
      @cor = Core.find(params[:id])
    end

    def cor_params
      params.require(:core).permit(:nmcor, :ativo)
    end
end
