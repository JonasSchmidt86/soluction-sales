class CollaboratorsBackoffice::MarcasController < CollaboratorsBackofficeController

  before_action :set_marca, only: [:edit, :update, :destroy, :toggle_status]

  def index
    @marcas = Marca.all
    @marca = Marca.new

    if params[:term].present?
      termo = params[:term].strip
      @marcas = @marcas.where("CAST(cod_marca AS TEXT) ILIKE ? OR nome ILIKE ?", "%#{termo}%", "%#{termo}%")
    end
    @marcas = @marcas.order(:nome).page(params[:page]).per(30)
  end

  def new
    @marca = Marca.new
  end


  def create
    @marca = Marca.new(marca_params)
    if @marca.save
      redirect_to collaborators_backoffice_marcas_path, notice: "Marca criada com sucesso."
    else
      @marcas = Marca.all
      render :index
    end
  end

  def edit 
  end

  def update
    if @marca.update(marca_params)
      redirect_to collaborators_backoffice_marcas_path, notice: "Marca atualizada com sucesso."
    else
      render :edit
    end
  end

  def destroy
    if pode_excluir?(@marca)
      @marca.destroy
      redirect_to collaborators_backoffice_marcas_path, notice: "Marca excluída com sucesso."
    else
      redirect_to collaborators_backoffice_marcas_path, alert: "Não é possível excluir. Existem produtos vinculados."
    end
  end

  private

  def set_marca
    @marca = Marca.find(params[:id])
  end

  def marca_params
    params.require(:marca).permit(:nome)
  end

  def pode_excluir?(marca)
    !Produto.where(marca: marca).exists?
  end
end
