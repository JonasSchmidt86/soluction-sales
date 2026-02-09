class CollaboratorsBackoffice::LancamentosdiversosController < CollaboratorsBackofficeController
    
    before_action :set_diverso, only: [:edit, :update, :destroy]

    def index
        inicio_mes = Date.current.beginning_of_month
        fim_mes    = Date.current.end_of_month

        @lancamentos_diversos = Lancamentosdiverso
        .unscoped
        .where(cod_empresa: current_collaborator.empresa.cod_empresa, datavencimento: nil)
        .where(
            "cod_lancamento NOT IN (
            SELECT cod_lancamentodiverso
            FROM lancamentoscaixa
            WHERE cod_empresa = ?
                AND datapagto BETWEEN ? AND ?
            )",
            current_collaborator.empresa.cod_empresa,
            inicio_mes,
            fim_mes
        )
        .order(:datainicio)
        .page(params[:page])
    end

    def edit
    end

    def new
        @lancamentosdiverso = Lancamentosdiverso.new
    end

    def create
        puts "PARAMS: #{params.inspect}"
        @lancamentosdiverso = Lancamentosdiverso.new(lancamentosdiverso_params)
        @lancamentosdiverso.cod_empresa = current_collaborator.empresa.cod_empresa
        if @lancamentosdiverso.save
            redirect_to collaborators_backoffice_lancamentosdiversos_path, notice: 'Lançamento criado com sucesso.'
        else
            puts "Erro ao salvar: #{@lancamentosdiverso.errors.full_messages}"
            @lancamentos_diversos = Lancamentosdiverso
            .unscoped
            .where(cod_empresa: current_collaborator.empresa.cod_empresa, datavencimento: nil)
            .order(:datainicio)
            .page(params[:page])
            render :new
        end
    end

    def destroy
        if Lancamentoscaixa.exists?(cod_lancamentodiverso: @lancamentosdiverso.id)
            redirect_to collaborators_backoffice_lancamentosdiversos_path, alert: 'Não é possível excluir este lançamento, pois há lançamentos caixa relacionados.'
        else
            @lancamentosdiverso.destroy
            redirect_to collaborators_backoffice_lancamentosdiversos_path, notice: 'Lançamento excluído com sucesso.'
        end
    end

    def update
        if @lancamentosdiverso.update(lancamentosdiverso_params)
            redirect_to collaborators_backoffice_lancamentosdiversos_path, notice: 'Lançamento atualizado com sucesso.'
        else
            render :edit
        end
    end

    private

    def set_diverso
        @lancamentosdiverso = Lancamentosdiverso.find(params[:id])
    end

    def lancamentosdiverso_params
        params.require(:lancamentosdiverso).permit(:descricao, :valor, :datainicio, :datavencimento, :entrada, :provisionada, :cod_empresa, :cod_funcionario, :cod_tphitorico)
    end
end
