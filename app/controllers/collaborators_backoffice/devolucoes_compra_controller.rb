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
    # Lista TODAS as operacoes ativas (saida e entrada). O usuario precisa poder
    # escolher no topo a MESMA operacao que esta cadastrada na regra do perfil
    # (algumas regras usam operacoes tipo "entrada", ex. Devolucao de venda).
    # O CFOP so e resolvido quando existe regra (perfil + operacao); sem regra,
    # fica em branco.
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(nome: "Devolucao de compra")
    @finalidades = DocumentoFiscal::FINALIDADES
    # Perfis de SAIDA para o seletor por item. A operacao da NF (topo) + o perfil
    # resolvem o CFOP; se o perfil nao tiver regra para a operacao, o CFOP fica
    # em branco (o usuario cadastra a regra ou informa o CFOP na mao).
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)

    # Pre-resolve, por item, o perfil (o do produto) e o CFOP pela regra desse
    # perfil para a operacao de devolucao. Sem regra, cai no CFOP do XML.
    # CFOP de cada item: regra do perfil do produto PARA A OPERACAO padrao
    # (devolucao de compra). Sem regra, fica em branco (usuario resolve). O CFOP
    # recalcula ao trocar a operacao do topo ou o perfil do item (via JS).
    resolver = Fiscal::CfopResolver.new(empresa: @compra.empresa, destino_uf: @compra.pessoa&.uf)
    @itens = @itens.map do |it|
      produto = Produto.find_by(cod_produto: it[:cod_produto])
      perfil  = produto&.perfil_tributario
      regra   = (@operacao_padrao && produto) ? resolver.regra_para(produto, @operacao_padrao) : nil
      cfop_regra = regra ? RegraFiscal.cfop_por_uf(regra.cfop_base, @compra.empresa&.uf, @compra.pessoa&.uf) : nil
      it.merge(
        cod_perfil_tributario: perfil&.cod_perfil_tributario,
        cfop_sugerido:         cfop_regra # nil = em branco quando nao ha regra
      )
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
  # perfil (destino = UF do fornecedor da compra). Sem regra (perfil + operacao),
  # retorna vazio e o CFOP fica em branco. Usado via AJAX ao trocar a operacao
  # (no topo ou por item).
  def resolver_cfop
    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "Devolucao de compra")
    produto  = Produto.find_by(cod_produto: params[:cod_produto])
    perfil   = PerfilTributario.find_by(cod_perfil_tributario: params[:cod_perfil_tributario])

    # CFOP vem da regra (perfil + operacao). Sem regra, retorna vazio (branco).
    cfop = nil
    if operacao && (perfil || produto)
      cfop = Fiscal::CfopResolver.new(empresa: @compra.empresa, destino_uf: @compra.pessoa&.uf)
                                 .cfop(produto, operacao, perfil: perfil)
    end

    render json: { cfop: cfop, origem: cfop.present? ? "regra" : "sem_regra" }
  rescue => e
    Rails.logger.error("[DevolucoesCompra#resolver_cfop] #{e.class} - #{e.message}")
    render json: { cfop: nil, origem: "erro" }
  end

  # POST .../compras/:compra_id/devolucao
  def create
    documento = montar_emissor.emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_compra_path(@compra),
                  notice: "NF-e de devolução autorizada. Chave: #{documento.chave_acesso}"
    else
      redirect_to collaborators_backoffice_compra_path(@compra),
                  alert: "Devolução #{documento.status}: #{documento.mensagem_sefaz}"
    end
  rescue DevolucaoInvalida,
         Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
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
  # Via AJAX: responde o PDF (sucesso) ou JSON com erro (falha). O front so
  # abre a aba quando o PDF chega; em erro, mostra o alerta na propria tela.
  def previsualizar
    preview = montar_emissor.pre_visualizar(tipo_arquivo: 1)
    if preview.sucesso?
      send_data preview.conteudo, filename: "previsualizacao-devolucao-compra-#{@compra.cod_compra}.pdf",
                type: "application/pdf", disposition: "inline"
    else
      render json: { erro: "Não foi possível pré-visualizar: #{preview.erro}" }, status: :unprocessable_entity
    end
  rescue DevolucaoInvalida,
         Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    render json: { erro: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("[DevolucoesCompra#previsualizar] compra #{@compra.cod_compra}: #{e.class} - #{e.message}")
    render json: { erro: "Falha ao pré-visualizar: #{e.message}" }, status: :unprocessable_entity
  end

  private

  # Monta o EmissorFiscal da devolucao a partir dos params do form (itens
  # editados, CFOP, natureza, finalidade). Retorna nil (apos redirecionar com
  # alerta) quando falta config ou nao ha itens. Usado por create e previsualizar.
  class DevolucaoInvalida < StandardError; end

  def montar_emissor
    config = FiscalConfig.find_by(cod_empresa: @compra.cod_empresa)
    raise DevolucaoInvalida, "Empresa sem configuração fiscal ativa." if config.nil? || !config.ativo?

    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "Devolucao de compra")

    extractor = Fiscal::DevolucaoCompraExtractor.new(@compra)
    itens = aplicar_edicoes(extractor.itens)
    chave = params[:chave_referencia].presence || extractor.chave_referencia

    raise DevolucaoInvalida, "Nenhum item para devolver." if itens.empty?

    finalidade = params[:finalidade].presence || 4

    builder = Fiscal::DevolucaoCompraBuilder.new(
      @compra, config: config, itens: itens, chave_referencia: chave,
      natureza_operacao: params[:natureza_operacao].presence || operacao&.natureza_operacao,
      cfop: params[:cfop].presence, modelo: 55, finalidade: finalidade,
      operacao: operacao # operacao da NF escolhida no topo (resolve CFOP/tributacao)
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
        icms_base:     imposto_override(ed["icms_base"],     ed["icms_base_auto"]),
        icms_valor:    imposto_override(ed["icms_valor"],    ed["icms_valor_auto"]),
        icms_aliquota: imposto_override(ed["icms_aliquota"], ed["icms_aliquota_auto"]),
        ipi_valor:     imposto_override(ed["ipi_valor"],     ed["ipi_valor_auto"]),
        ipi_aliquota:  imposto_override(ed["ipi_aliquota"],  ed["ipi_aliquota_auto"])
      }.compact

      # Perfil escolhido na linha. Se o PRODUTO ainda nao tem perfil, grava o
      # escolhido como padrao do produto (fica salvo para as proximas vezes).
      cod_perfil = ed["cod_perfil_tributario"].presence
      aplicar_perfil_ao_produto(it[:cod_produto], cod_perfil) if cod_perfil

      it.merge(
        quantidade:       MoedaBr.parse(ed["quantidade"]).presence || it[:quantidade],
        valor_unitario:   MoedaBr.parse(ed["valor_unitario"]).presence || it[:valor_unitario],
        valor_total:      (MoedaBr.parse(ed["quantidade"]).to_d.nonzero? && MoedaBr.parse(ed["valor_unitario"]).to_d.nonzero?) ?
                            (MoedaBr.parse(ed["quantidade"]).to_d * MoedaBr.parse(ed["valor_unitario"]).to_d) : it[:valor_total],
        cfop:             ed["cfop"].to_s.gsub(/\D/, "").presence, # CFOP por item (sobrepoe o geral)
        cod_perfil_tributario: cod_perfil, # perfil escolhido na tela (prioridade sobre o do produto)
        imposto_override: override.presence
      )
    end
  end

  # Grava o perfil escolhido como padrao do produto, mas SO quando o produto
  # ainda nao tem perfil (nao sobrescreve um perfil ja definido).
  def aplicar_perfil_ao_produto(cod_produto, cod_perfil)
    produto = Produto.find_by(cod_produto: cod_produto)
    return if produto.nil? || produto.cod_perfil_tributario.present?
    produto.update_column(:cod_perfil_tributario, cod_perfil)
  rescue => e
    Rails.logger.error("[DevolucoesCompra#aplicar_perfil_ao_produto] #{e.class} - #{e.message}")
  end

  # Interpreta o campo de imposto editado em relacao ao valor automatico
  # pre-preenchido (campo *_auto). Regras:
  #   - vazio E o auto tinha valor  -> usuario APAGOU: zera (retorna 0);
  #   - vazio E o auto tambem vazio  -> nao mexeu: nil;
  #   - preenchido = auto            -> nao mexeu: nil (deixa o builder usar o XML);
  #   - preenchido != auto           -> override com o valor digitado.
  # Assim, apagar o campo tira o imposto (nao volta ao valor do XML).
  def imposto_override(valor, valor_auto)
    bruto = valor.to_s.strip
    auto  = MoedaBr.parse(valor_auto)

    if bruto.empty?
      return auto.present? ? 0 : nil   # apagou um campo que tinha valor -> zera
    end

    v = MoedaBr.parse(valor)
    return nil if v.nil?
    return v if auto.nil?
    (v.to_d.round(2) == auto.to_d.round(2)) ? nil : v
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
