class CollaboratorsBackoffice::Report::RepAtendimentosController < CollaboratorsBackofficeController

  def index
    query = Atendimento.includes(:origem, :funcionario, :pessoa)
                       .where(cod_empresa: current_collaborator.cod_empresa)

    data_inicial = params[:dataInicial].presence || Time.current.strftime("%d/%m/%Y")
    data_final   = params[:dataFinal].presence   || Date.today.end_of_month.strftime("%d/%m/%Y")

    query = query.where(
      "DATE(data_atendimento) BETWEEN TO_DATE(?, 'DD/MM/YYYY') AND TO_DATE(?, 'DD/MM/YYYY')",
      data_inicial, data_final
    )

    if params[:term].present?
      query = query.where("atendimentos.nome ILIKE ?", "%#{params[:term]}%")
    end

    if params[:cod_funcionario].present?
      query = query.where(cod_funcionario: params[:cod_funcionario])
    end

    if params[:vendeu].present?
      query = query.where(vendeu: params[:vendeu] == '1')
    end

    per_page = params[:per_page].present? ? params[:per_page].to_i : 30

    @atendimentos = if params[:per_page] == 'Todas'
      query.order(data_atendimento: :desc)
    else
      query.order(data_atendimento: :desc).page(params[:page]).per(per_page)
    end

    @total   = @atendimentos.respond_to?(:total_count) ? @atendimentos.total_count : @atendimentos.size
    @venderam = query.where(vendeu: true).count
  end

end
