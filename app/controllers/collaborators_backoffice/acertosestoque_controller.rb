class CollaboratorsBackoffice::AcertosestoqueController < CollaboratorsBackofficeController

  def destroy
    acerto = Acertoestoque.find(params[:id])
    acerto.destroy
    redirect_to collaborators_backoffice_acertosestoque_index_path(params.permit(:per_page, :term, :data_inicio, :data_fim, :page).to_h), notice: "Acerto removido com sucesso!"
  end

  def new
  end

  def create
    acerto = Acertoestoque.new(
      cod_empresa:   current_collaborator.cod_empresa,
      cod_produto:   params[:cod_produto],
      cod_cor:       params[:cod_cor],
      tipo:          params[:tipo],
      quantidade:    params[:quantidade],
      descricao:     params[:descricao],
      datacadastro:  Time.current
    )
    if acerto.save
      redirect_to collaborators_backoffice_acertosestoque_index_path, notice: "Acerto registrado com sucesso!"
    else
      redirect_to collaborators_backoffice_acertosestoque_index_path, alert: "Erro ao registrar acerto."
    end
  end

  def index
    cod_empresa = current_collaborator.cod_empresa
    data_inicio = params[:data_inicio].present? ? Date.strptime(params[:data_inicio], "%d/%m/%Y") : Date.today.beginning_of_month
    data_fim    = params[:data_fim].present?    ? Date.strptime(params[:data_fim],    "%d/%m/%Y") : Date.today.end_of_month

    query = Acertoestoque.includes(:produto, :cor)
                         .where(cod_empresa: cod_empresa)
                         .where("DATE(datacadastro) BETWEEN ? AND ?", data_inicio, data_fim)
                         .order(datacadastro: :desc)

    if params[:term].present?
      term = params[:term].strip
      query = query.joins(:produto).where(
        "produto.cod_produto::varchar = ? OR produto.nome ILIKE ?",
        term, "#{term}%"
      )
    end

    per_page = params[:per_page] == 'Todas' ? nil : (params[:per_page].to_i > 0 ? params[:per_page].to_i : 30)
    @acertos = per_page ? query.page(params[:page]).per(per_page) : query

    @data_inicio = data_inicio.strftime("%d/%m/%Y")
    @data_fim    = data_fim.strftime("%d/%m/%Y")
  end

end
