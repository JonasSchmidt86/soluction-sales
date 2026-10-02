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

    # Pre-resolve o CFOP de cada item pela regra fiscal do perfil do produto
    # para a operacao padrao. Sem regra, cai no CFOP convertido do XML (saida).
    resolver = Fiscal::CfopResolver.new(empresa: @compra.empresa, destino_uf: @compra.pessoa&.uf)
    @itens = @itens.map do |it|
      produto = Produto.find_by(cod_produto: it[:cod_produto])
      cfop_regra = @operacao_padrao && produto ? resolver.cfop(produto, @operacao_padrao) : nil
      it.merge(cfop_sugerido: cfop_regra || cfop_convertido(it[:cfop_original]))
    end

    if @itens.empty?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "A compra não tem itens para devolver."
    end
  end

  # GET .../compras/:compra_id/devolucao/baixar_xml
  # Baixa o XML da NOTA DE ENTRADA (compra) buscando no provedor pela chave
  # (ObterArquivoNotaFiscal, tipo documento = entrada). Util quando o XML local
  # nao esta disponivel (ex.: storage de producao).
  def baixar_xml
    chave = Fiscal::DevolucaoCompraExtractor.new(@compra).chave_referencia
    if chave.blank?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "Compra sem chave de NF-e para buscar o XML."
      return
    end

    config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
    if config.nil? || !config.ativo?
      redirect_to collaborators_backoffice_compra_path(@compra), alert: "Empresa sem configuração fiscal ativa."
      return
    end

    arquivo = FiscalService.new(config).obter_arquivo(chave: chave, file_type: 1, tipo_documento: 0)
    if arquivo.sucesso?
      send_data arquivo.conteudo, filename: "nfe-entrada-#{chave}.xml",
                type: "application/xml", disposition: "attachment"
    else
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "XML da entrada indisponível: #{arquivo.erro}"
    end
  rescue => e
    Rails.logger.error("[DevolucoesCompra#baixar_xml] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_compra_path(@compra), alert: "Falha ao obter o XML: #{e.message}"
  end

  # GET .../compras/:compra_id/devolucao/resolver_cfop?cod_produto=&cod_operacao_fiscal=
  # Resolve o CFOP de um produto para a operacao escolhida, pela regra fiscal do
  # perfil (destino = UF do fornecedor da compra). Fallback: converte o CFOP de
  # entrada do item. Usado via AJAX ao trocar a operacao (no topo ou por item).
  def resolver_cfop
    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal])
    produto  = Produto.find_by(cod_produto: params[:cod_produto])

    cfop = nil
    origem = "fallback"
    if operacao && produto
      cfop = Fiscal::CfopResolver.new(empresa: @compra.empresa, destino_uf: @compra.pessoa&.uf)
                                 .cfop(produto, operacao)
      origem = "regra" if cfop.present?
    end
    cfop ||= cfop_convertido(params[:cfop_original])

    render json: { cfop: cfop, origem: origem }
  rescue => e
    Rails.logger.error("[DevolucoesCompra#resolver_cfop] #{e.class} - #{e.message}")
    render json: { cfop: nil, origem: "erro" }
  end

  # POST .../compras/:compra_id/devolucao
  def create
    emissor = montar_emissor
    return if emissor.nil? # ja redirecionou com alerta

    documento = emissor.emitir

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

  # POST .../compras/:compra_id/devolucao/previsualizar
  # Gera o DANFE de PRE-VISUALIZACAO da devolucao (sem transmitir a SEFAZ),
  # usando os mesmos itens/CFOP/finalidade do formulario.
  def previsualizar
    emissor = montar_emissor
    return if emissor.nil?

    preview = emissor.pre_visualizar(tipo_arquivo: 1)
    if preview.sucesso?
      send_data preview.conteudo, filename: "previsualizacao-devolucao-compra-#{@compra.cod_compra}.pdf",
                type: "application/pdf", disposition: "inline"
    else
      redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                  alert: "Não foi possível pré-visualizar: #{preview.erro}"
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra), alert: e.message
  rescue => e
    Rails.logger.error("[DevolucoesCompra#previsualizar] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    redirect_to new_collaborators_backoffice_compra_devolucao_path(@compra),
                alert: "Falha ao pré-visualizar: #{e.message}"
  end

  private

  # Monta o EmissorFiscal da devolucao a partir dos params do form (itens
  # editados, CFOP, natureza, finalidade). Retorna nil (apos redirecionar com
  # alerta) quando falta config ou nao ha itens. Usado por create e previsualizar.
  def montar_emissor
    config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
    if config.nil? || !config.ativo?
      redirect_to collaborators_backoffice_compra_path(@compra), alert: "Empresa sem configuração fiscal ativa."
      return nil
    end

    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "Devolucao de compra")

    extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
    itens = aplicar_edicoes(extractor.itens)
    chave = params[:chave_referencia].presence || extractor.chave_referencia

    if itens.empty?
      redirect_to collaborators_backoffice_compra_path(@compra), alert: "Nenhum item para devolver."
      return nil
    end

    finalidade = params[:finalidade].presence || 4

    builder = Fiscal::DevolucaoCompraBuilder.new(
      @compra, config: config, itens: itens, chave_referencia: chave,
      natureza_operacao: params[:natureza_operacao].presence || operacao&.natureza_operacao,
      cfop: params[:cfop].presence, modelo: 55, finalidade: finalidade
    )

    origem = Fiscal::OrigemDevolucao.new(@compra.empresa)
    Fiscal::EmissorFiscal.new(
      origem, modelo: 55, operacao: operacao,
      cod_funcionario: current_collaborator.cod_funcionario,
      builder: builder, cod_compra: @compra.cod_compra, finalidade: finalidade
    )
  end

  # Converte um CFOP de entrada (1/2/3xxx) para saida (5/6/7xxx), para o
  # fallback quando o produto nao tem regra fiscal de devolucao.
  def cfop_convertido(cfop_entrada)
    c = cfop_entrada.to_s.gsub(/\D/, "")
    return nil if c.length < 4
    { "1" => "5", "2" => "6", "3" => "7" }.fetch(c[0], c[0]) + c[1..]
  end

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

      # Overrides manuais de imposto (base/valor ICMS e valor IPI). So contam
      # como override quando o usuario ALTEROU o valor em relacao ao rateio
      # automatico (comparado ao campo *_auto escondido). Assim, mudar so a
      # quantidade NAO congela o imposto no valor pre-preenchido.
      override = {
        icms_base:  imposto_override(ed["icms_base"],  ed["icms_base_auto"]),
        icms_valor: imposto_override(ed["icms_valor"], ed["icms_valor_auto"]),
        ipi_valor:  imposto_override(ed["ipi_valor"],  ed["ipi_valor_auto"])
      }.compact

      it.merge(
        quantidade:       MoedaBr.parse(ed["quantidade"]).presence || it[:quantidade],
        valor_unitario:   MoedaBr.parse(ed["valor_unitario"]).presence || it[:valor_unitario],
        valor_total:      (MoedaBr.parse(ed["quantidade"]).to_d.nonzero? && MoedaBr.parse(ed["valor_unitario"]).to_d.nonzero?) ?
                            (MoedaBr.parse(ed["quantidade"]).to_d * MoedaBr.parse(ed["valor_unitario"]).to_d) : it[:valor_total],
        cfop:             ed["cfop"].to_s.gsub(/\D/, "").presence, # CFOP por item (sobrepoe o geral)
        imposto_override: override.presence
      )
    end
  end

  # Retorna o valor do imposto como override SOMENTE se o usuario mudou o campo
  # em relacao ao valor automatico (rateado) pre-preenchido. Senao, nil (deixa
  # o builder ratear pela quantidade). Compara em centavos para evitar ruido de
  # formatacao.
  def imposto_override(valor, valor_auto)
    v = MoedaBr.parse(valor)
    return nil if v.nil?
    auto = MoedaBr.parse(valor_auto)
    return v if auto.nil?
    (v.to_d.round(2) == auto.to_d.round(2)) ? nil : v
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
