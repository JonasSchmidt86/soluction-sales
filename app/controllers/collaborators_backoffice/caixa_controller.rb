class CollaboratorsBackoffice::CaixaController < CollaboratorsBackofficeController
    
    before_action :set_caixa, only: [:edit, :update, :destroy]
    # before_action :params_caixa, only: [:update]

    def index
        @caixas = Caixa.where("cod_empresa = ?", current_collaborator.cod_empresa).order("datafechamento desc").page(params[:page])
    end

    def update

        if !@caixa.nil? && @caixa.datafechamento.nil?

            # @caixa.datafechamento = 0.day.from_now
            @caixa.datafechamento = DateTime.now
            @caixa.cod_funcionariofechamento = current_collaborator.cod_funcionario
            @caixa.valorfechamento = (@caixa.valorabertura + @caixa.valorentradas) - @caixa.valorsaidas
            if @caixa.save
                redirect_to collaborators_backoffice_caixa_index_path, notice: "Caixa fechado com sucesso!"
            else 
                # redirect_to collaborators_backoffice_caixa_index_path, notice: "Erro ao fechar caixa!"
            end
        else 
            redirect_to collaborators_backoffice_caixa_index_path , notice: "Caixa já esta fechado!"
        end
    end

    def edit
    end

    def new
        cx2 = Caixa.where(" cod_empresa = ? ", current_collaborator.cod_empresa).last
        if cx2.datafechamento == nil
            redirect_to collaborators_backoffice_caixa_index_path , notice: "Caixa já esta Aberto"
        else
            @caixa = Caixa.new do |cx|
                cx.cod_empresa = current_collaborator.cod_empresa
                cx.dataabertura = DateTime.now
                cx.valorabertura = cx2.valorfechamento      
                cx.cod_funcionarioabertura = current_collaborator.cod_funcionario
                cx.valorentradas = 0.0
                cx.valorsaidas = 0.0
                cx.valorfechamento = 0.0
                cx.cod_funcionariofechamento = nil
            end
            
            if @caixa.save
                redirect_to collaborators_backoffice_caixa_index_path , notice: "Caixa Aberto com sucesso!"
            else
                redirect_to collaborators_backoffice_caixa_index_path , notice: "Erro ao abrir caixa"
            end
        end
    end

    def create

    end

    def destroy
        if @caixa.lancamentoscaixa.any?
            redirect_to collaborators_backoffice_caixa_index_path , notice: "Não é possivel apagar caixa!"
        else @caixa.destroy
            redirect_to collaborators_backoffice_caixa_index_path , notice: "Caixa Apagado!"
        end
    end

    private 

    def params_caixa
        params.require(:caixa).permit(:datafechamento, :valorfechamento )
    end

    def set_caixa
        @caixa = Caixa.find(params[:id])
    end
    
end
