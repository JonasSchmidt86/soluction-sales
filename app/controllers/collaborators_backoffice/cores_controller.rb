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
    @cor = Core.new(ativo: true)
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
    if @cor.destroy
      redirect_to collaborators_backoffice_cores_path, notice: 'Cor excluída com sucesso.'
    else
      # Supondo que a exclusão falhou por restrição de associação
      if @cor.update(ativo: false)
        redirect_to collaborators_backoffice_cores_path, notice: 'Cor está associada a produtos e foi marcada como inativa.'
      else
        redirect_to collaborators_backoffice_cores_path, alert: 'Não foi possível excluir ou desativar a cor.'
      end
    end
  end

  private

    def set_cor
      @cor = Core.find(params[:id])
    end

    def cor_params
      params.require(:core).permit(:nmcor, :ativo)
    end
end
