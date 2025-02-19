class CollaboratorsBackoffice::LancamentosdiversosController < CollaboratorsBackofficeController
    
    before_action :set_diverso, only: [:edit, :update, :destroy]

    def index
        @lancamentos = Lancamentoscaixa
            .where("cod_empresa = ? and date(datapagto) = date( ? ) ", current_collaborator.empresa.cod_empresa,  (Date.today - 4)).page(params[:page]);
    end

    def edit
    end

    def new
        @lancamentosdiversos = Lancamentosdiversos.new
    end

    def create
    end

    def destroy
    end

    def update
    end

    private 

end
