class CollaboratorsBackoffice::LancamentosdiversosController < CollaboratorsBackofficeController
    
    before_action :set_diverso, only: [:edit, :update, :destroy]

    def index
        inicio_mes = Date.current.beginning_of_month
        fim_mes    = Date.current.end_of_month

        @lancamentos_diversos = Lancamentosdiverso
        .unscoped
        .where(cod_empresa: current_collaborator.empresa.cod_empresa)
        .order(:cod_tphitorico)
        .page(params[:page])
    end

    def edit
    end

    def new
        @lancamentosdiverso = Lancamentosdiverso.new
    end

    def create
        @lancamentosdiverso = Lancamentosdiverso.new(lancamentosdiverso_params)
        @lancamentosdiverso.cod_empresa = current_collaborator.empresa.cod_empresa
        if @lancamentosdiverso.save
            redirect_to collaborators_backoffice_lancamentosdiversos_path, notice: 'Lançamento criado com sucesso.'
        else
            puts "Erro ao salvar: #{@lancamentosdiverso.errors.full_messages}"
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

    def pagamentos
        inicio_mes = Date.current.beginning_of_month
        fim_mes    = Date.current.end_of_month

        dataInicial = Date.strptime(params[:data_inicial], "%d/%m/%Y") rescue nil
        dataFinal   = Date.strptime(params[:data_final], "%d/%m/%Y") rescue nil


        @q = Lancamentosdiverso.ransack(params[:q])
        @lancamentos_diversos = @q.result
                                    .unscoped
                                    .where(cod_empresa: current_collaborator.empresa.cod_empresa, provisionada: true)
                                    .where("cod_lancamento NOT IN (SELECT cod_lancamentodiverso FROM lancamentoscaixa WHERE datapagto BETWEEN  ? AND ? and cod_lancamentodiverso IS NOT NULL)", inicio_mes, fim_mes)

        # Apply filters for descricao, historico, and date range
        @lancamentos_diversos = @lancamentos_diversos.where("descricao ILIKE ?", "%#{params[:descricao_cont]}%") if params[:descricao_cont].present?
        @lancamentos_diversos = @lancamentos_diversos.where("cod_tphitorico = ?", params[:cod_historico]) if params[:cod_historico].present?

        if dataInicial && dataFinal
            @lancamentos_diversos = @lancamentos_diversos.where(
                "EXTRACT(DAY FROM datainicio) BETWEEN ? AND ?",
                dataInicial.day,
                dataFinal.day
            )
        elsif dataInicial
            @lancamentos_diversos = @lancamentos_diversos.where(
                "EXTRACT(DAY FROM datainicio) >= ?",
                dataInicial.day
            )
        elsif dataFinal
            @lancamentos_diversos = @lancamentos_diversos.where("EXTRACT(DAY FROM datainicio) <= ?", dataFinal.day)
        end

        # @lancamentos_diversos = @lancamentos_diversos.order(Arel.sql("EXTRACT(DAY FROM datainicio) desc")).page(params[:page])
        @lancamentos_diversos = @lancamentos_diversos.order(:cod_tphitorico).page(params[:page])
    end

    private

    def set_diverso
        @lancamentosdiverso = Lancamentosdiverso.find(params[:id])
    end

    def lancamentosdiverso_params
        params.require(:lancamentosdiverso).permit(:descricao, :valor, :datainicio, :datavencimento, :entrada, :provisionada, :cod_empresa, :cod_funcionario, :cod_tphitorico)
    end
end
