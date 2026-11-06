# Dashboard de analytics do catalogo publico (portfolio, produtos, buscas e cliques
# no WhatsApp). Spec: .kiro/specs/analytics-portfolio. Dados: site_events.
#
# Controllers de relatorio nao entram no CONTROLLER_RESOURCE_MAP (a URL direta ficaria
# aberta a qualquer colaborador), entao a permissao e checada aqui, como no fiscal.
class CollaboratorsBackoffice::Report::RepSiteAnalyticsController < CollaboratorsBackofficeController
  RECURSO  = "report_site_analytics".freeze
  PADRAO_DIAS = 30  # periodo padrao: ultimos 30 dias, incluindo hoje
  MAX_DIAS = 366    # limite do intervalo, para a consulta nao ficar pesada

  before_action :autorizar_analytics!

  def index
    @inicio, @fim = periodo
    @relatorio = SiteAnalyticsReport.new(@inicio, @fim).call
  end

  private

  # [inicio, fim] a partir de params[:inicio]/[:fim] (ISO, yyyy-mm-dd). Sem datas validas:
  # ultimos 30 dias. Datas invertidas sao trocadas, o futuro e cortado em hoje e o
  # intervalo e limitado a MAX_DIAS.
  def periodo
    hoje = Date.current
    fim  = [parse_data(params[:fim]) || hoje, hoje].min
    ini  = parse_data(params[:inicio]) || (fim - (PADRAO_DIAS - 1))
    ini, fim = fim, ini if ini > fim
    ini = fim - (MAX_DIAS - 1) if (fim - ini).to_i >= MAX_DIAS
    [ini, fim]
  end

  def parse_data(valor)
    Date.iso8601(valor.to_s) if valor.present?
  rescue ArgumentError
    nil
  end

  def autorizar_analytics!
    return if access_control.can_view?(RECURSO)

    redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
  end
end
