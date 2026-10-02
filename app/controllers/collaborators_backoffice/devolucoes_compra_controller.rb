class CollaboratorsBackoffice::DevolucoesCompraController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_compra

  # GET .../compras/:compra_id/devolucao/new
  # Tela de revisao: itens espelhados do XML da compra, CFOP/natureza editaveis.
  def new
    extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
    @itens = extractor.itens
    @chave_referencia = extractor.chave_referencia
    @tem_xml = extractor.tem_xml?
    @operacoes = OperacaoFiscal.where(tipo: "saida").order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(nome: "Devolucao de compra")
    @finalidades = DocumentoFiscal::FINALIDADES

    if @itens.empty?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "A compra não tem itens para devolver."
    end
  end

  # POST .../compras/:compra_id/devolucao
  def create
    config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
    if config.nil? || !config.ativo?
      redirect_to collaborators_backoffice_compra_path(@compra), alert: "Empresa sem configuração fiscal ativa."
      return
    end

    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "Devolucao de compra")

    extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
    itens = aplicar_edicoes(extractor.itens)
    chave = params[:chave_referencia].presence || extractor.chave_referencia

    if itens.empty?
      redirect_to collaborators_backoffice_compra_path(@compra), alert: "Nenhum item para devolver."
      return
    end

    finalidade = params[:finalidade].presence || 4

    builder = Fiscal::DevolucaoCompraBuilder.new(
      @compra, config: config, itens: itens, chave_referencia: chave,
      natureza_operacao: params[:natureza_operacao].presence || operacao&.natureza_operacao,
      cfop: params[:cfop].presence, modelo: 55, finalidade: finalidade
    )

    origem = Fiscal::OrigemDevolucao.new(@compra.empresa)
    documento = Fiscal::EmissorFiscal.new(
      origem, modelo: 55, operacao: operacao,
      cod_funcionario: current_collaborator.cod_funcionario,
      builder: builder, cod_compra: @compra.cod_compra, finalidade: finalidade
    ).emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  notice: "NF-e de devolução autorizada. Chave: #{documento.chave_acesso}"
    else
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "Devolução #{documento.status}: #{documento.mensagem_sefaz}"
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra), alert: e.message
  rescue => e
    Rails.logger.error("[DevolucoesCompra#create] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                alert: "Falha ao emitir devolução: #{e.message}"
  end

  private

  def set_compra
    @compra = Compra.find_by(cod_compra: params[:compra_id])
    redirect_to collaborators_backoffice_report_buy_path, alert: "Compra não encontrada." if @compra.nil?
  end

  # Aplica as edicoes do form (quantidade/valor por item) sobre os itens
  # espelhados. Itens desmarcados (sem checkbox "devolver") sao removidos.
  def aplicar_edicoes(itens_base)
    editados = params[:itens]
    return itens_base if editados.blank?
    editados = editados.values if editados.is_a?(ActionController::Parameters)

    itens_base.each_with_index.filter_map do |it, i|
      ed = editados[i] || editados[i.to_s] || {}
      ed = ed.to_unsafe_h if ed.respond_to?(:to_unsafe_h)
      next unless ActiveModel::Type::Boolean.new.cast(ed["devolver"]) # so marcados

      it.merge(
        quantidade:     MoedaBr.parse(ed["quantidade"]).presence || it[:quantidade],
        valor_unitario: MoedaBr.parse(ed["valor_unitario"]).presence || it[:valor_unitario],
        valor_total:    (MoedaBr.parse(ed["quantidade"]).to_d.nonzero? && MoedaBr.parse(ed["valor_unitario"]).to_d.nonzero?) ?
                          (MoedaBr.parse(ed["quantidade"]).to_d * MoedaBr.parse(ed["valor_unitario"]).to_d) : it[:valor_total]
      )
    end
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
