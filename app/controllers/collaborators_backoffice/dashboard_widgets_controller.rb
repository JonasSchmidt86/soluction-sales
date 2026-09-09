class CollaboratorsBackoffice::DashboardWidgetsController < CollaboratorsBackofficeController

  # GET /collaborators_backoffice/dashboard_widgets
  # Lista os widgets configuráveis do colaborador (apenas os permitidos).
  def index
    widgets = current_layout.select { |w| widget_allowed?(w) }
    # A lista do modal usa uma ORDEM FIXA (a do catálogo/DEFAULT_LAYOUT),
    # independente da ordem que o usuário deu aos widgets no dashboard.
    ordem_fixa = DashboardWidget::DEFAULT_LAYOUT.each_with_index.to_h
    widgets = widgets.sort_by { |w| ordem_fixa[w.widget_type] || 999 }
    render json: widgets.map { |w|
      {
        id: w.id,
        widget_type: w.widget_type,
        label: w.label,
        col_span: w.span,
        row_span: w.rows,
        visible: w.visible,
        position: w.position
      }
    }
  end

  # PATCH /collaborators_backoffice/dashboard_widgets/:id
  # Atualiza visibilidade e/ou tamanho de um widget.
  def update
    widget = scoped_widgets.find(params[:id])
    attrs = widget_params.to_h
    # Garante largura (1..12) e altura (1..8) dentro dos limites
    if attrs.key?('col_span')
      attrs['col_span'] = attrs['col_span'].to_i.clamp(DashboardWidget::MIN_SPAN, DashboardWidget::MAX_SPAN)
    end
    if attrs.key?('row_span')
      attrs['row_span'] = attrs['row_span'].to_i.clamp(DashboardWidget::MIN_ROWS, DashboardWidget::MAX_ROWS)
    end
    if widget.update(attrs)
      render json: { ok: true, col_span: widget.col_span, row_span: widget.row_span, visible: widget.visible }
    else
      render json: { ok: false, errors: widget.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /collaborators_backoffice/dashboard_widgets/reorder
  # Recebe a nova ordem dos ids e persiste a posição de cada widget.
  def reorder
    ids = Array(params[:order]).map(&:to_i)
    scope = scoped_widgets.where(id: ids)
    ids.each_with_index do |id, index|
      scope.find { |w| w.id == id }&.update_column(:position, index)
    end
    render json: { ok: true }
  end

  # POST /collaborators_backoffice/dashboard_widgets/reset
  # Remove a configuração atual e recria o layout padrão.
  def reset
    scoped_widgets.delete_all
    DashboardWidget.ensure_defaults!(
      current_collaborator.cod_funcionario,
      current_collaborator.cod_empresa
    )
    render json: { ok: true }
  end

  private

  def scoped_widgets
    # Layout é único por usuário (independente da empresa)
    DashboardWidget.for_funcionario(current_collaborator.cod_funcionario)
  end

  def current_layout
    DashboardWidget.layout_for(
      current_collaborator.cod_funcionario,
      current_collaborator.cod_empresa
    )
  end

  def widget_allowed?(widget)
    widget.resource.nil? || access_control.can_view?(widget.resource)
  end

  def widget_params
    params.require(:dashboard_widget).permit(:visible, :col_span, :row_span)
  end
end
