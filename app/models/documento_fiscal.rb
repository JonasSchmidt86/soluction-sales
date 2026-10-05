class DocumentoFiscal < ApplicationRecord
  self.table_name = "documento_fiscal"
  self.primary_key = "cod_documento_fiscal"

  STATUSES = %w[rascunho enviada autorizada rejeitada denegada cancelada erro].freeze

  # Finalidade da NF-e (campo finNFe do layout SEFAZ). Lista fechada.
  FINALIDADES = {
    1 => "Normal",
    2 => "Complementar",
    3 => "Ajuste",
    4 => "Devolução"
  }.freeze

  # Rotulo legivel da finalidade de um codigo (ou do proprio documento).
  def self.finalidade_label(cod)
    FINALIDADES[cod.to_i] || cod.to_s
  end

  def finalidade_label
    self.class.finalidade_label(finalidade)
  end

  belongs_to :empresa, class_name: "Empresa",
             foreign_key: "cod_empresa", primary_key: "cod_empresa"
  belongs_to :venda, class_name: "Venda",
             foreign_key: "cod_venda", primary_key: "cod_venda", optional: true
  belongs_to :compra, class_name: "Compra",
             foreign_key: "cod_compra", primary_key: "cod_compra", optional: true

  has_many :eventos, class_name: "DocumentoFiscalEvento",
           foreign_key: "cod_documento_fiscal", primary_key: "cod_documento_fiscal",
           dependent: :destroy, inverse_of: :documento_fiscal

  validates :modelo, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :autorizadas, -> { where(status: "autorizada") }
  scope :pendentes,   -> { where(status: %w[rascunho enviada]) }
  scope :da_empresa,  ->(cod) { where(cod_empresa: cod) }

  def autorizada?
    status == "autorizada"
  end

  def cancelada?
    status == "cancelada"
  end

  def nfce?
    modelo.to_i == 65
  end

  def nfe?
    modelo.to_i == 55
  end

  def modelo_nome
    nfce? ? "NFC-e" : "NF-e"
  end

  # NF de devolucao de compra (vinculada a uma compra, finalidade 4).
  def devolucao_compra?
    cod_compra.present?
  end

  # Mapeia o status do FiscalResult (masculino: autorizado/rejeitado/...)
  # para o status do documento (feminino: autorizada/rejeitada/...).
  MAPA_STATUS = {
    "autorizado" => "autorizada",
    "rejeitado"  => "rejeitada",
    "cancelado"  => "cancelada",
    "denegado"   => "denegada",
    "processando" => "enviada",
    "erro"       => "erro"
  }.freeze

  # Cancela esta NF autorizada via provedor e registra o evento (quem/quando/
  # motivo) em documento_fiscal_evento. Retorna o FiscalResult.
  #
  # justificativa: texto (minimo 15 caracteres, exigido pela SEFAZ).
  # cod_funcionario: quem esta cancelando (para o historico).
  #
  # Levanta ArgumentError se nao autorizada ou justificativa invalida.
  def cancelar!(justificativa:, cod_funcionario:)
    just = justificativa.to_s.strip
    raise ArgumentError, "Só é possível cancelar uma NF autorizada." unless autorizada?
    raise ArgumentError, "A justificativa precisa ter ao menos 15 caracteres." if just.length < 15

    config = empresa.fiscal_config
    raise ArgumentError, "Empresa sem configuração fiscal." if config.nil?

    result = FiscalService.new(config).cancelar({ chave: chave_acesso, protocolo: protocolo }, just)

    # Registra o evento ANTES de mudar o status, guardando o desfecho da SEFAZ.
    eventos.create!(
      tipo:            "cancelamento",
      status:          result.sucesso? ? "registrado" : "rejeitado",
      justificativa:   just[0, 255],
      cod_funcionario: cod_funcionario,
      protocolo:       result.protocolo,
      xml_base64:      result.xml,
      mensagem_sefaz:  result.mensagem.to_s[0, 255],
      registrado_em:   Time.current
    )

    # Só muda o documento se a SEFAZ homologou o cancelamento.
    if result.sucesso?
      aplicar_resultado!(result)
      estornar_estoque_fiscal!(cod_funcionario)
    end
    result
  end

  # Estorna o estoque fiscal (qtdfiscal) ao cancelar a NF — devolve o que a
  # emissão havia baixado, respeitando controla_estoque de cada item.
  # Reconstrói os itens a partir dos ESTOQUE_LOGS de SAIDA_FISCAL deste documento
  # (o que a emissao de fato baixou). Assim funciona tanto para NF de venda quanto
  # para NF AVULSA (sem venda) e devolucao — nao depende de reabrir a venda/builder.
  def estornar_estoque_fiscal!(cod_funcionario = nil)
    itens = itens_estoque_fiscal_do_log
    return if itens.empty?

    Fiscal::EstoqueFiscalService.new(
      cod_empresa:     cod_empresa,
      itens:           itens,
      cod_referencia:  cod_documento_fiscal,
      cod_funcionario: cod_funcionario,
      observacao:      "Cancelamento NF (doc #{cod_documento_fiscal})"
    ).estornar!
  rescue => e
    Rails.logger.error("[DocumentoFiscal#estornar_estoque_fiscal] doc #{cod_documento_fiscal}: #{e.class} - #{e.message}")
  end

  # Reconstrói os itens que tiveram baixa fiscal (qtdfiscal) na EMISSAO deste
  # documento, lendo os estoque_logs de SAIDA_FISCAL. Soma por produto+cor (caso
  # haja mais de um log). Quantidade = total baixado (movida negativa -> positiva).
  def itens_estoque_fiscal_do_log
    logs = EstoqueLog.where(cod_referencia: cod_documento_fiscal,
                            operacao: "SAIDA_FISCAL", origem: "NFE_FISCAL")
    agrupado = Hash.new(0.to_d)
    logs.each do |l|
      chave = [l.cod_produto, l.cod_cor]
      agrupado[chave] += l.qtdfiscal_movida.to_d.abs
    end
    agrupado.map do |(cod_produto, cod_cor), qtd|
      next if qtd.zero?
      { cod_produto: cod_produto, cod_cor: cod_cor, quantidade: qtd, controla_estoque: "proprio" }
    end.compact
  end

  # Reconcilia o status deste documento com a SEFAZ via ConsultarNotaFiscal.
  # Util quando a emissao ficou "enviada"/"erro" por queda de rede mas a nota
  # pode ter sido autorizada. Atualiza status, chave, protocolo e XML/DANFE
  # (pede arquivos). Retorna a FiscalConsulta.
  #
  # Localiza por chave (se houver) ou pelo IdentificadorInterno derivado da
  # venda (VENDA-<cod>); sem nenhum dos dois, nao consulta.
  def reconciliar_status!
    config = empresa.fiscal_config
    return nil if config.nil? || !config.ativo?

    filtros = { modelo: modelo.to_i, retornar_arquivos: true }
    if chave_acesso.present?
      filtros[:chave] = chave_acesso
    elsif cod_venda.present?
      filtros[:identificador] = "VENDA-#{cod_venda}"
    else
      return nil
    end

    consulta = FiscalService.new(config).consultar(filtros)
    return consulta unless consulta&.encontrada?

    novo_status = MAPA_STATUS_CONSULTA[consulta.situacao]
    attrs = {}
    attrs[:status]         = novo_status if novo_status.present?
    attrs[:chave_acesso]   = consulta.chave     if consulta.chave.present?
    attrs[:protocolo]      = consulta.protocolo if consulta.protocolo.present?
    attrs[:numero]         = consulta.numero    if consulta.numero.present?
    attrs[:serie]          = consulta.serie     if consulta.serie.present?
    attrs[:xml_base64]     = consulta.xml_base64 if consulta.xml_base64.present?
    attrs[:danfe_base64]   = consulta.pdf_base64 if consulta.pdf_base64.present?
    attrs[:mensagem_sefaz] = consulta.mensagem.to_s[0, 255] if consulta.mensagem.present?
    attrs[:emitido_em]     = Time.current if novo_status == "autorizada" && emitido_em.blank?

    update(attrs) if attrs.any?
    sincronizar_venda! if status == "autorizada"
    consulta
  rescue => e
    Rails.logger.error("[DocumentoFiscal#reconciliar_status] doc #{cod_documento_fiscal}: #{e.class} - #{e.message}")
    nil
  end

  # Situacao da CONSULTA (FiscalConsulta) -> status do documento.
  MAPA_STATUS_CONSULTA = {
    autorizada: "autorizada",
    cancelada:  "cancelada",
    rejeitada:  "rejeitada",
    denegada:   "denegada",
    enviada:    "enviada"
  }.freeze

  # Aplica o resultado da emissao (FiscalResult) a este documento.
  def aplicar_resultado!(result)
    self.status            = MAPA_STATUS[result.status.to_s] || "erro"
    self.chave_acesso      = result.chave if result.chave.present?
    self.protocolo         = result.protocolo if result.protocolo.present?
    self.numero            = result.numero if result.numero.present?
    self.serie             = result.serie if result.serie.present?
    self.xml_base64        = result.xml if result.xml.present?
    self.danfe_base64      = result.bruto&.dig("Base64File") if result.bruto.is_a?(Hash)
    self.cod_status_sefaz  = result.bruto&.dig("ReturnNF", "CodStatusRespostaSefaz") if result.bruto.is_a?(Hash)
    self.mensagem_sefaz    = result.mensagem.to_s[0, 255]
    self.emitido_em        = Time.current if result.sucesso?
    save!

    sincronizar_venda! if status == "autorizada"
  end

  # Quando a NF-e e autorizada, grava o numero da nota na venda de origem
  # (numeronf + datanf), para aparecer no relatorio (venda_nfe) e no DANFE.
  #
  # OBS: NAO altera o numeronf dos ITENS aqui. O ajuste de qtdfiscal na emissao
  # (que depende de itemvenda.numeronf > 0) sera tratado numa etapa separada,
  # junto da selecao de itens por NF.
  def sincronizar_venda!
    return if venda.nil? || numero.blank?
    venda.update_columns(numeronf: numero, datanf: emitido_em || Time.current)
  rescue => e
    Rails.logger.error("[DocumentoFiscal#sincronizar_venda!] doc #{cod_documento_fiscal}: #{e.class} - #{e.message}")
  end
end
