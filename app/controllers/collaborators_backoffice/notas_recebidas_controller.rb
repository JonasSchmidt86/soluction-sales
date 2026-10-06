class CollaboratorsBackoffice::NotasRecebidasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_nota, only: [:importar]

  # Painel de notas de ENTRADA recebidas de fornecedores (automatico via SEFAZ).
  def index
    @cod_empresa = current_collaborator.cod_empresa
    @inicio, @fim = periodo

    escopo = NotaRecebida.da_empresa(@cod_empresa)
                         .where(data_emissao: @inicio.beginning_of_day..@fim.end_of_day)
    escopo = escopo.where(status_sefaz: params[:status]) if params[:status].present?
    if params[:integrado] == "1"
      escopo = escopo.integradas
    elsif params[:integrado] == "0"
      escopo = escopo.nao_integradas
    end

    @notas = escopo.recentes.page(params[:page])

    # Alerta: notas que viraram compra mas foram CANCELADAS na SEFAZ.
    @alertas_canceladas = NotaRecebida.da_empresa(@cod_empresa).integradas.canceladas
  end

  # Busca na SEFAZ as notas de entrada do periodo e grava as novas.
  def sincronizar
    inicio, fim = periodo
    res = Fiscal::NotasRecebidasService.new(current_collaborator.empresa)
                                       .sincronizar!(dt_inicio: inicio, dt_fim: fim)
    if res.erro
      redirect_to notas_recebidas_path(filtros), alert: "Falha ao buscar notas: #{res.mensagem}"
    else
      redirect_to notas_recebidas_path(filtros), notice: "Busca concluída: #{res.mensagem}"
    end
  end

  # Atualiza o status SEFAZ das notas ja conhecidas (detecta cancelamento).
  def sincronizar_status
    inicio, fim = periodo
    res = Fiscal::NotasRecebidasService.new(current_collaborator.empresa)
                                       .sincronizar!(dt_inicio: inicio, dt_fim: fim)
    redirect_to notas_recebidas_path(filtros),
                notice: "Status atualizado: #{res.mensagem}"
  end

  # Importar = levar ao fluxo de compra existente (produtoxmls#new monta a compra
  # a partir do XmlFile). Reusa toda a tela de conferencia atual.
  def importar
    if @nota.xml_file_id.blank?
      redirect_to notas_recebidas_path, alert: "Nota sem XML baixado para importar."
      return
    end
    redirect_to new_collaborators_backoffice_produtoxml_path(@nota.xml_file_id)
  end

  private

  def set_nota
    @nota = NotaRecebida.da_empresa(current_collaborator.cod_empresa).find(params[:id])
  end

  def periodo
    ini = parse_data(params[:inicio]) || Date.today.beginning_of_month
    fim = parse_data(params[:fim])    || Date.today
    ini, fim = fim, ini if ini > fim
    [ini, fim]
  end

  def filtros
    { inicio: params[:inicio], fim: params[:fim], status: params[:status], integrado: params[:integrado] }.compact
  end

  def parse_data(v)
    Date.parse(v) if v.present?
  rescue ArgumentError
    nil
  end

  def notas_recebidas_path(opts = {})
    collaborators_backoffice_notas_recebidas_path(opts)
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
