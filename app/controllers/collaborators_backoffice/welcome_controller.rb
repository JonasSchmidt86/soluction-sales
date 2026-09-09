class CollaboratorsBackoffice::WelcomeController < CollaboratorsBackofficeController

    def index
      agente = request.user_agent
      @dispositivo =
        if agente =~ /Windows|Macintosh/
          'Computador'
        else
          'Outro'
        end

      # Carrega o layout de widgets do colaborador (cria o padrão na primeira vez)
      layout = DashboardWidget.layout_for(
        current_collaborator.cod_funcionario,
        current_collaborator.cod_empresa
      )

      # Mantém apenas os widgets visíveis e permitidos pelo controle de acesso
      @widgets = layout.select do |w|
        next false unless w.visible
        w.resource.nil? || access_control.can_view?(w.resource)
      end

      # Dados calculados sob demanda apenas para os widgets ativos
      @dashboard_data = DashboardDataService.new(current_collaborator)
    end
end
