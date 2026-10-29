class CollaboratorsBackoffice::FiscalDashboardController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  # Painel do modulo fiscal: resumo de emissoes, valores, alertas e grafico.
  def index
    @cod_empresa = current_collaborator.cod_empresa
    @inicio, @fim = periodo

    docs = DocumentoFiscal.where(cod_empresa: @cod_empresa)
    @docs_periodo = docs.where(created_at: @inicio.beginning_of_day..@fim.end_of_day)

    # ---- Cartoes de resumo (no periodo) ----
    autorizadas = @docs_periodo.where(status: "autorizada")
    @qtd_nfe   = autorizadas.where(modelo: 55).where("finalidade <> 4 OR finalidade IS NULL").count
    @qtd_nfce  = autorizadas.where(modelo: 65).count
    @qtd_cancel = @docs_periodo.where(status: "cancelada").count
    @qtd_problema = @docs_periodo.where(status: %w[rejeitada erro denegada]).count

    # ---- Notas RECEBIDAS no periodo (entradas registradas da SEFAZ) ----
    # Antes contava as COMPRAS da empresa; agora conta as NOTAS RECEBIDAS
    # (NotaRecebida) com emissao no periodo — ou seja, o que entrou pra mim,
    # independente de ja ter virado compra. O cartao linka pro relatorio de
    # notas recebidas.
    notas_receb = NotaRecebida.da_empresa(@cod_empresa)
                              .where(data_emissao: @inicio.beginning_of_day..@fim.end_of_day)
    @valor_compras_nf = notas_receb.sum(:valor_total)
    @qtd_compras_nf = notas_receb.count
    # Faturadas = notas recebidas que ja viraram compra (integradas).
    faturadas = notas_receb.integradas
    @qtd_receb_faturadas = faturadas.count
    @valor_receb_faturadas = faturadas.sum(:valor_total)

    @valor_autorizado = autorizadas.sum(:valor_total)
    @valor_nfe   = autorizadas.where(modelo: 55).sum(:valor_total)
    @valor_nfce  = autorizadas.where(modelo: 65).sum(:valor_total)

    # ---- Alertas / pendencias (independe do periodo) ----
    @pendentes = docs.where(status: %w[rascunho enviada])
                     .where("created_at < ?", 30.minutes.ago)
                     .order(created_at: :desc).limit(20)
    @com_problema = docs.where(status: %w[rejeitada erro denegada])
                        .order(cod_documento_fiscal: :desc).limit(20)
    @config = FiscalConfig.find_by(cod_empresa: @cod_empresa)
    @homologacao = @config&.homologacao?

    # ---- Serie diaria para o grafico (empilhado por status) ----
    @serie = serie_diaria(@docs_periodo)

    # ---- Recebimentos (para BAIXO no grafico): notas recebidas FATURADAS ----
    # So as que ja viraram compra, contadas no DIA DA COMPRA (compra.datacompra),
    # e nao no dia de emissao da nota. Compras canceladas ficam de fora.
    recebidas = NotaRecebida.da_empresa(@cod_empresa).integradas.joins(:compra)
                            .merge(Compra.where(cancelada: [false, nil]))
                            .where("compra.datacompra::date BETWEEN ? AND ?", @inicio, @fim)
    por_dia = recebidas.group("compra.datacompra::date").count # { Date => qtd }
    valor_por_dia = recebidas.group("compra.datacompra::date").sum(:valor_total) # { Date => R$ }
    @serie[:recebida] = (@inicio..@fim).map { |d| por_dia[d].to_i }
    @serie[:recebida_valor] = (@inicio..@fim).map { |d| valor_por_dia[d].to_f.round(2) }
    # Datas dd/mm/aaaa de cada ponto: usadas no clique para abrir o report_buy do dia.
    @serie[:dias_br] = (@inicio..@fim).map { |d| d.strftime("%d/%m/%Y") }
    @valor_recebido_faturadas = recebidas.sum(:valor_total)

    # ---- Ultimos documentos ----
    # includes(:venda): exibimos cod_vendaempresa na coluna Origem (evita N+1).
    @ultimos = docs.includes(:venda).order(cod_documento_fiscal: :desc).limit(12)
  end

  private

  # Periodo [inicio, fim] a partir dos params (datas) ou mes atual por padrao.
  def periodo
    ini = parse_data(params[:inicio]) || Date.today.beginning_of_month
    fim = parse_data(params[:fim])    || Date.today
    ini, fim = fim, ini if ini > fim
    [ini, fim]
  end

  def parse_data(v)
    Date.parse(v) if v.present?
  rescue ArgumentError
    nil
  end

  # Monta { labels: [datas], datasets: { autorizada: [...], cancelada: [...],
  # problema: [...] } } para o grafico de barras empilhado.
  def serie_diaria(scope)
    dias = (@inicio..@fim).to_a
    labels = dias.map { |d| d.strftime("%d/%m") }

    por_dia_status = scope.group("date(created_at)", :status).count # { [date, status] => n }

    cat = ->(status) do
      dias.map do |d|
        por_dia_status.select { |(data, st), _| data == d && pertence?(st, status) }
                      .values.sum
      end
    end

    {
      labels: labels,
      autorizada: cat.call(:autorizada),
      cancelada:  cat.call(:cancelada),
      problema:   cat.call(:problema)
    }
  end

  def pertence?(status, grupo)
    case grupo
    when :autorizada then status == "autorizada"
    when :cancelada  then status == "cancelada"
    when :problema   then %w[rejeitada erro denegada].include?(status)
    else false
    end
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.can_view?("fiscal_dashboard")
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
