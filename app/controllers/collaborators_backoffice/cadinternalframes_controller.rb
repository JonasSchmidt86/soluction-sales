class CollaboratorsBackoffice::CadinternalframesController < CollaboratorsBackofficeController
  before_action :set_cadinternalframe, only: [:show, :edit, :update, :destroy]
  
  def index
    @cadinternalframes = Cadinternalframe.all.order(:jmenu)
  end

  def show
  end
  
  def new
    @cadinternalframe = Cadinternalframe.new
    @cadinternalframe.cod_frame = Cadinternalframe.next_code
    @available_routes = get_available_routes
  end
  
  def create
    @cadinternalframe = Cadinternalframe.new(cadinternalframe_params)
    
    if @cadinternalframe.save
      redirect_to collaborators_backoffice_cadinternalframes_path, notice: "Layout cadastrado com sucesso!"
    else
      @available_routes = get_available_routes
      render :new
    end
  end
  
  def edit
    @available_routes = get_available_routes
  end
  
  def update
    if @cadinternalframe.update(cadinternalframe_params)
      redirect_to collaborators_backoffice_cadinternalframes_path, notice: "Layout atualizado com sucesso!"
    else
      @available_routes = get_available_routes
      render :edit
    end
  end
  
  def destroy
    if @cadinternalframe.destroy
      redirect_to collaborators_backoffice_cadinternalframes_path, notice: "Layout excluído com sucesso!"
    else
      redirect_to collaborators_backoffice_cadinternalframes_path, alert: "Erro ao excluir layout!"
    end
  end
  
  private
  
  def get_available_routes
  # Obtém todas as rotas do Rails
  all_routes = []
  
  Rails.application.routes.routes.each do |route|
    # Pula rotas sem nome
    next unless route.name

    route_name = route.name.to_s
    
    # Filtra apenas rotas do namespace collaborators_backoffice
    if route_name.start_with?('new_collaborators_backoffice_') || route_name.start_with?('edit_collaborators_backoffice_') || route_name.start_with?('collaborators_backoffice_') 
      

      puts "--------------------------------------------------------------------------------"
      puts "Processing route: #{route.name}"
      puts "Processing route: #{route.path.spec.to_s.gsub(/\(\.:format\)/, '')}"
      puts "--------------------------------------------------------------------------------"

      # Verifica se a rota termina com _index_path, _new_path ou _edit_path
      # ou se contém index, new ou edit no meio do nome
        puts "Processing route: #{route_name}"
        begin
          # Adiciona a rota ao array
          all_routes << { name: route_name, path: route.path.spec.to_s.gsub(/\(\.:format\)/, '') }
        rescue => e
          # Ignora rotas que causam erro
          Rails.logger.debug "Erro ao processar rota #{route_name}: #{e.message}"
      end
    end
  end
  
  # Remove rotas que já estão cadastradas
  existing_urls = Cadinternalframe.pluck(:url).compact
  
  # Se estiver editando, inclui a URL atual
  if @cadinternalframe && @cadinternalframe.persisted? && @cadinternalframe.url.present?
    existing_urls = existing_urls - [@cadinternalframe.url]
  end
  
  # Retorna apenas rotas que não estão cadastradas
  all_routes.reject { |route| existing_urls.include?(route[:path]) }
end


  def set_cadinternalframe
    @cadinternalframe = Cadinternalframe.find(params[:id])
  end
  
  def cadinternalframe_params
    params.require(:cadinternalframe).permit(:cod_frame, :jmenu, :nminternalframe, :tamanhomenu, :tituloframe, :url)
  end
end