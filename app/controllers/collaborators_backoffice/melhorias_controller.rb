class CollaboratorsBackoffice::MelhoriasController < CollaboratorsBackofficeController

  before_action :set_melhoria, only: [:show, :edit, :update, :destroy]
  before_action :verificar_admin, only: [:edit, :update, :destroy]

  def index
    if admin?
      @melhorias = Melhoria.includes(:empresa, :funcionario)
    else
      @melhorias = Melhoria.where(cod_funcionario: current_collaborator.cod_funcionario)
    end

    @melhorias = @melhorias.por_status(params[:status])
                           .por_tipo(params[:tipo])
                           .por_prioridade(params[:prioridade])
                           .por_funcionario(params[:cod_funcionario])
                           .busca(params[:busca])

    if params[:data_inicio].present? && params[:data_fim].present?
      inicio = Date.parse(params[:data_inicio]) rescue nil
      fim = Date.parse(params[:data_fim]) rescue nil
      @melhorias = @melhorias.por_periodo(inicio, fim) if inicio && fim
    end

    @melhorias = @melhorias.recentes.page(params[:page])

    # Para os filtros de funcionário (apenas admin vê o filtro de todos)
    @funcionarios = Funcionario.joins(:funcionarioempresas)
                               .where(funcionarioempresa: { cod_empresa: current_collaborator.cod_empresa, ativo: true })
                               .includes(:pessoa)
  end

  def show
    @comentario = MelhoriaComentario.new
    @comentarios = @melhoria.comentarios.cronologico.includes(:funcionario)
    @historicos = @melhoria.historicos.cronologico.includes(:funcionario)
  end

  def new
    @melhoria = Melhoria.new
  end

  def create
    @melhoria = Melhoria.new(melhoria_params)
    @melhoria.cod_funcionario = current_collaborator.cod_funcionario
    @melhoria.cod_empresa = current_collaborator.cod_empresa
    @melhoria.status = :aberto

    if @melhoria.save
      redirect_to collaborators_backoffice_melhoria_path(@melhoria),
                  notice: 'Solicitação criada com sucesso!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @melhoria.assign_attributes(melhoria_admin_params)
    registrar_historico_alteracoes

    if @melhoria.save
      redirect_to collaborators_backoffice_melhoria_path(@melhoria),
                  notice: 'Solicitação atualizada com sucesso!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @melhoria.anexos.purge if @melhoria.anexos.attached?
    @melhoria.destroy
    redirect_to collaborators_backoffice_melhorias_path, notice: 'Solicitação excluída com sucesso!'
  end

  # POST /melhorias/:id/comentar
  def comentar
    @melhoria = Melhoria.find(params[:id])
    @comentario = @melhoria.comentarios.build(comentario_params)
    @comentario.cod_funcionario = current_collaborator.cod_funcionario

    if @comentario.save
      redirect_to collaborators_backoffice_melhoria_path(@melhoria),
                  notice: 'Comentário adicionado!'
    else
      @comentarios = @melhoria.comentarios.cronologico.includes(:funcionario)
      @historicos = @melhoria.historicos.cronologico.includes(:funcionario)
      render :show, status: :unprocessable_entity
    end
  end

  # DELETE /melhorias/:id/remover_anexo/:anexo_id
  def remover_anexo
    @melhoria = Melhoria.find(params[:id])

    unless admin?
      redirect_to collaborators_backoffice_melhoria_path(@melhoria), alert: 'Acesso negado.'
      return
    end

    anexo = @melhoria.anexos.find(params[:anexo_id])
    anexo.purge
    redirect_to collaborators_backoffice_melhoria_path(@melhoria),
                notice: 'Anexo removido.'
  end

  private

  def set_melhoria
    @melhoria = Melhoria.find(params[:id])
  end

  def melhoria_params
    params.require(:melhoria).permit(:titulo, :descricao, :tipo, :prioridade, anexos: [])
  end

  def melhoria_admin_params
    params.require(:melhoria).permit(:status, :prioridade, :responsavel_id, anexos: [])
  end

  def comentario_params
    params.require(:melhoria_comentario).permit(:comentario, anexos: [])
  end

  def admin?
    current_collaborator.funcionario.permissao.nivel == 1
  end

  def verificar_admin
    unless admin?
      redirect_to collaborators_backoffice_melhorias_path, alert: 'Acesso negado.'
    end
  end

  def registrar_historico_alteracoes
    campos_monitorados = %w[status prioridade responsavel_id]

    campos_monitorados.each do |campo|
      if @melhoria.send("#{campo}_changed?")
        valor_anterior = @melhoria.send("#{campo}_was")
        valor_novo = @melhoria.send(campo)

        # Para responsavel_id, registrar o nome em vez do ID
        if campo == 'responsavel_id'
          valor_anterior = nome_funcionario(valor_anterior)
          valor_novo = nome_funcionario(valor_novo)
          campo_label = 'responsavel'
        else
          campo_label = campo
        end

        @melhoria.historicos.build(
          cod_funcionario: current_collaborator.cod_funcionario,
          campo: campo_label,
          valor_anterior: valor_anterior.to_s,
          valor_novo: valor_novo.to_s
        )
      end
    end
  end

  def nome_funcionario(cod)
    return nil if cod.blank?
    func = Funcionario.find_by(cod_funcionario: cod)
    func&.pessoa_nome || func&.usuario || "Funcionário ##{cod}"
  end

end
