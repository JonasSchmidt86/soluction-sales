class CollaboratorsBackofficeController < ApplicationController

    before_action :authenticate_collaborator!
    before_action :authorize_resource!
    #before_action :verificar_horario_comercial
    layout 'collaborators_backoffice'

    def check_cpf_cnpj
        cpf_cnpj = params[:cpf_cnpj].gsub(/\D/, '')  # Remove todos os caracteres não numéricos
        pessoa = Pessoa.find_by(cpf_cnpj: cpf_cnpj)
        
        # Verifica se uma pessoa foi encontrada
        if pessoa
          puts pessoa
          render json: pessoa
        else
          render json: { status: 'not_found' }
        end
  
      end

    # Helper disponível em controllers e views
    def access_control
      @access_control ||= AccessControlService.new(current_collaborator)
    end
    helper_method :access_control

    private

    # Mapeamento de controller_name → resource do controle de acesso
    CONTROLLER_RESOURCE_MAP = {
      'welcome' => 'welcome',
      'caixa' => 'caixa',
      'vendas' => 'vendas',
      'orcamentos' => 'orcamentos',
      'contas_pag_rec' => 'contas_pag_rec',
      'produtos' => 'produtos',
      'pessoas' => 'pessoas',
      'funcionarios' => 'funcionarios',
      'collaborators' => 'collaborators',
      'compras' => 'compras',
      'pedidos_compras' => 'pedidos_compras',
      'empresa_estoque' => 'empresa_estoque',
      'acertosestoque' => 'acertosestoque',
      'lancamentosdiversos' => 'lancamentosdiversos',
      'lancamentoscaixas' => 'lancamentoscaixas',
      'cores' => 'cores',
      'marcas' => 'marcas',
      'grupos' => 'grupos',
      'melhorias' => 'melhorias',
      'commission_rules' => 'commission_rules',
      'commission_assignments' => 'commission_assignments',
      'commission_periods' => 'commission_periods',
      'commission_adjustments' => 'commission_adjustments',
      'notas_fiscais' => 'notas_fiscais',
      'xml_files' => 'xml_files',
      'whatsapp_contacts' => 'whatsapp_contacts',
      'access_roles' => 'access_roles',
      'atendimentos' => 'atendimentos'
    }.freeze

    # Mapeamento de action → tipo de permissão
    ACTION_PERMISSION_MAP = {
      'index' => :view,
      'show' => :view,
      'new' => :create,
      'create' => :create,
      'edit' => :edit,
      'update' => :edit,
      'destroy' => :delete,
      'editar_itens' => :edit,
      'atualizar_itens' => :edit,
      'atualizar_vendedor' => :edit,
      'calculate' => :edit,
      'finalize' => :edit,
      'mark_as_paid' => :edit,
      'reopen' => :edit,
      'cancel' => :edit,
      'detect_cancelled' => :edit,
      'assign' => :edit,
      'unassign' => :edit,
      'print' => :view,
      'converter_venda' => :create,
      'comentar' => :create,
      'pagamentos' => :view,
      'estoque' => :view
    }.freeze

    def authorize_resource!
      return unless current_collaborator

      # Permitir que o colaborador atualize a si mesmo (troca de empresa)
      if controller_name == 'collaborators' && %w[edit update].include?(action_name)
        return if params[:id].to_i == current_collaborator.id
      end

      # Permitir que o colaborador atualize seu próprio avatar
      if controller_name == 'funcionarios' && %w[edit update].include?(action_name)
        return if params[:id].to_i == current_collaborator.cod_funcionario
      end

      resource = current_resource_name
      return unless resource # Se não está mapeado, libera (controllers auxiliares)

      permission_action = current_permission_action
      return unless permission_action # Actions não mapeadas (ex: custom actions) → libera

      unless access_control.can?(permission_action, resource)
        Rails.logger.warn "[AccessControl] BLOQUEADO: func=#{current_collaborator.cod_funcionario} emp=#{current_collaborator.cod_empresa} controller=#{controller_name} action=#{action_name} resource=#{resource} permission=#{permission_action}"
        redirect_to collaborators_backoffice_welcome_index_path,
                    alert: 'Acesso negado. Você não possui permissão para acessar este recurso.'
      end
    end

    def current_resource_name
      CONTROLLER_RESOURCE_MAP[controller_name]
    end

    def current_permission_action
      ACTION_PERMISSION_MAP[action_name] || :view
    end

    def verificar_horario_comercial
        return unless current_collaborator&.empresa&.controlar_horario?
        
        unless current_collaborator.empresa.horario_comercial?
            sign_out current_collaborator
            # redirect_to collaborators_backoffice_collaborators_path(alert: "Acesso negado fora do horário comercial!")
            redirect_to new_collaborator_session_path(alert: "Acesso negado fora do horário comercial!")
        end
    end

end
