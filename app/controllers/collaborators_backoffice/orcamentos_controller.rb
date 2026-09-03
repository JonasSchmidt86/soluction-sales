class CollaboratorsBackoffice::OrcamentosController < CollaboratorsBackofficeController
  before_action :set_orcamento, only: [:show, :edit, :update, :destroy, :converter_venda, :print]

  def index
    @orcamentos = Orcamento.where(cod_empresa: current_collaborator.cod_empresa)
                           .includes(:pessoa, :funcionario)

    # Detecta se o usuário submeteu o formulário de filtro
    filtrado = params[:filtrado].present?

    # Status: por padrão (sem filtrar) traz apenas pendentes.
    # Se o usuário filtrou, usa o status escolhido (ou todos, se vazio).
    @status_selecionado = filtrado ? params[:status] : 'pendente'
    if @status_selecionado.present?
      @orcamentos = @orcamentos.where(status: @status_selecionado)
    end

    # Data: só filtra quando o usuário informar. Sem data = todos os períodos.
    if params[:data_inicio].present?
      data_inicio = Date.strptime(params[:data_inicio], '%d/%m/%Y') rescue nil
      @orcamentos = @orcamentos.where('data_orcamento >= ?', data_inicio.beginning_of_day) if data_inicio
    end

    if params[:data_fim].present?
      data_fim = Date.strptime(params[:data_fim], '%d/%m/%Y') rescue nil
      @orcamentos = @orcamentos.where('data_orcamento <= ?', data_fim.end_of_day) if data_fim
    end

    # Paginação (mesmo padrão do relatório de vendas): 30 por padrão,
    # configurável via per_page. "Todas" (per_page = 0) desativa a paginação.
    @orcamentos = @orcamentos.order(data_orcamento: :desc)
    if params[:per_page].present? && params[:per_page].to_i.zero?
      # "Todas" selecionado: não pagina
      @orcamentos = @orcamentos.all
    else
      per_page = params[:per_page].to_i.zero? ? 30 : params[:per_page].to_i
      @orcamentos = @orcamentos.page(params[:page]).per(per_page)
    end
  end

  def show
    @itens = @orcamento.itens_orcamentos.includes(:produto, :cor)
  end

  def new
    @orcamento = Orcamento.new(
      cod_empresa: current_collaborator.cod_empresa,
      cod_funcionario: current_collaborator.cod_funcionario,
      data_orcamento: Time.current
    )
    @orcamento.itens_orcamentos.build
  end

  def create
    @orcamento = Orcamento.new(orcamento_params)
    @orcamento.cod_empresa = current_collaborator.cod_empresa
    @orcamento.cod_funcionario = current_collaborator.cod_funcionario

    if @orcamento.save
      redirect_to collaborators_backoffice_orcamento_path(@orcamento), notice: 'Orçamento criado com sucesso.'
    else
      render :new
    end
  end

  def edit
    @orcamento.nome_pessoa = @orcamento.pessoa.nome
    # Formata valores para evitar problemas com máscara JS
    @orcamento.itens_orcamentos.each do |item|
      item.valorunitario = '%.2f' % item.valorunitario if item.valorunitario
      item.valor_desconto = '%.2f' % (item.valor_desconto || 0)
      item.valor_acrescimo = '%.2f' % (item.valor_acrescimo || 0)
    end
  end

  def update
    if @orcamento.update(orcamento_params)
      redirect_to collaborators_backoffice_orcamento_path(@orcamento), notice: 'Orçamento atualizado.'
    else
      render :edit
    end
  end

  def destroy
    @orcamento.destroy
    redirect_to collaborators_backoffice_orcamentos_path, notice: 'Orçamento excluído.'
  end

  def converter_venda
    redirect_to new_collaborators_backoffice_venda_path(orcamento_id: @orcamento.cod_orcamento)
  end

  def print
    render layout: false
  end

  private

  def set_orcamento
    @orcamento = Orcamento.find(params[:id])
  end

  def orcamento_params
    puts params.inspect
    params.require(:orcamento).permit(
      :cod_pessoa, :nome_pessoa, :cod_funcionario, :data_orcamento, :data_validade, :valortotal, 
      :desconto, :acrescimo, :status, :observacoes,
      itens_orcamentos_attributes: [:id, :cod_produto, :cod_cor, :cod_empresa, :quantidade, 
                                     :valorunitario, :valor_desconto, :valor_acrescimo, :_destroy]
    )
  end
end
