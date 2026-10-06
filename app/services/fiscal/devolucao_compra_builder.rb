module Fiscal
  # Fonte neutra para o EmissorFiscal numa devolucao de compra: expoe empresa e
  # cod_venda (nil, para sempre criar documento novo). O builder e injetado,
  # entao o emissor nao itera itens daqui.
  class OrigemDevolucao
    attr_reader :empresa
    def initialize(empresa)
      @empresa = empresa
    end

    def cod_venda
      nil
    end
  end

  # Monta o "documento neutro" da NF-e de DEVOLUCAO DE COMPRA (finalidade 4),
  # espelhando os impostos destacados na nota de compra original (via
  # DevolucaoCompraExtractor). O destinatario e o FORNECEDOR da compra.
  #
  # Responde a mesma interface que o DocumentoFiscalBuilder (montar +
  # itens_estoque_fiscal), para ser injetado no EmissorFiscal.
  #
  # Parametros editaveis pelo usuario (variam por fornecedor):
  #   natureza_operacao: ex "Devolucao de compra" / "Remessa para conserto"
  #   cfop: CFOP completo a usar em todos os itens (ex 5202/6202/5915...).
  #   itens: lista do extractor (ja com impostos espelhados); pode vir editada.
  class DevolucaoCompraBuilder
    def initialize(compra, config:, itens:, chave_referencia: nil,
                   natureza_operacao: "Devolucao de compra", cfop: nil, modelo: 55,
                   finalidade: 4, operacao: nil)
      @compra    = compra
      @config    = config
      @itens     = Array(itens)
      @chave_ref = chave_referencia
      @natureza  = natureza_operacao
      @cfop      = cfop
      @modelo    = modelo
      @finalidade = (finalidade.presence && finalidade.to_i) || 4
      @empresa   = compra.empresa
      @fornecedor = compra.pessoa
      # Operacao da NF escolhida no topo (Devolucao de compra, Remessa p/ conserto...).
      # A tributacao de cada item vem da regra do perfil PARA ESSA operacao.
      @operacao = operacao || OperacaoFiscal.find_by(nome: "Devolucao de compra")
      @resolver = CfopResolver.new(empresa: @empresa, destino_uf: @fornecedor&.uf)
    end

    def montar
      {
        modelo:               @modelo,
        finalidade:           @finalidade,
        natureza:             @natureza.presence || "Devolucao de compra",
        # Fornecedor sem IE = nao contribuinte -> consumidor final (exigencia da
        # SEFAZ, rejeicao 696). Com IE = contribuinte -> consumidor final false.
        consumidor_final:     !fornecedor_contribuinte?,
        indicador_presenca:   0, # nao se aplica (operacao entre empresas)
        identificador_interno: "DEVCOMPRA-#{@compra.cod_compra}",
        nf_referencia:        Array(@chave_ref).reject(&:blank?),
        cliente:              montar_fornecedor,
        produtos:             montar_produtos,
        pagamentos:           montar_pagamentos,
        enviar_email:         false
      }.compact
    end

    # Fornecedor e contribuinte de ICMS quando possui Inscricao Estadual.
    def fornecedor_contribuinte?
      @fornecedor&.rg_ie.to_s.gsub(/\D/, "").present?
    end

    # Itens para baixa de ESTOQUE FISCAL. Numa devolucao de compra a mercadoria
    # SAI (devolvida ao fornecedor) -> baixa qtdfiscal. controla_estoque: proprio.
    def itens_estoque_fiscal
      @itens.map do |it|
        {
          cod_produto:      it[:cod_produto],
          cod_cor:          it[:cod_cor],
          quantidade:       it[:quantidade].to_d,
          controla_estoque: "proprio"
        }
      end
    end

    private

    def montar_fornecedor
      return nil if @fornecedor.blank?
      contribuinte = fornecedor_contribuinte?
      {
        "CpfCnpj"     => digitos(@fornecedor.cpf_cnpj),
        "NmCliente"   => @fornecedor.nome,
        # IndicadorIe: 1 = contribuinte ICMS; 9 = nao contribuinte. Coerente com
        # consumidor_final para evitar a rejeicao 696.
        "IndicadorIe" => contribuinte ? 1 : 9,
        "Ie"          => contribuinte ? @fornecedor.rg_ie.to_s.gsub(/\D/, "") : nil,
        "Endereco"    => endereco_fornecedor
      }.compact
    end

    def endereco_fornecedor
      return nil if @fornecedor.uf.blank?
      {
        "Cep"          => digitos(@fornecedor.cep),
        "Logradouro"   => @fornecedor.endereco,
        "Numero"       => @fornecedor.numero,
        "Bairro"       => @fornecedor.bairro,
        "CodMunicipio" => @fornecedor.cod_municipio_ibge,
        "Municipio"    => @fornecedor.cidade&.nome,
        "Uf"           => @fornecedor.uf
      }.compact
    end

    def montar_produtos
      raise DocumentoFiscalBuilder::DadoFiscalAusente, "Devolucao sem itens" if @itens.empty?

      # Bloqueia a emissao/pre-visualizacao quando algum item NAO tem regra fiscal
      # para a operacao escolhida (perfil + operacao do topo). Sem regra, nao ha
      # de onde tirar CFOP/CST com seguranca (espelhar o CST cru do XML rejeita no
      # Simples). O usuario deve cadastrar a regra ou trocar o perfil do item.
      sem_regra = @itens.reject { |it| regra_do_item(it) }
      if sem_regra.any?
        nomes = sem_regra.map { |it| it[:descricao].presence || "produto #{it[:cod_produto]}" }
        raise DocumentoFiscalBuilder::DadoFiscalAusente,
              "Sem regra fiscal para a operacao '#{@operacao&.nome}' nos itens: " \
              "#{nomes.join('; ')}. Cadastre a regra no perfil ou troque o perfil do item."
      end

      @itens.each_with_index.map do |it, idx|
        {
          "NmProduto"        => it[:descricao],
          "CodProdutoServico"=> it[:cod_produto].to_s,
          "EAN"              => it[:ean].presence,
          "NCM"              => it[:ncm],
          "UnidadeComercial" => it[:unidade].presence || "UN",
          "Quantidade"       => it[:quantidade].to_f,
          "ValorUnitario"    => it[:valor_unitario].to_f,
          "ValorTotal"       => it[:valor_total].to_f,
          "CFOP"             => cfop_do_item(it),
          "OrigemProduto"    => (it[:origem].presence || "0").to_i,
          # Referencia item a item a NF de compra original (se houver chave).
          "ChaveAcessoReferenciada" => @chave_ref.presence,
          "NItemReferenciado"       => (idx + 1),
          "Imposto"          => imposto_do_item(it)
        }.compact
      end
    end

    # Monta o Imposto do item no modelo HIBRIDO:
    #   - CST/CSOSN e aliquotas vem da REGRA do perfil (sempre existe aqui: itens
    #     sem regra sao bloqueados em montar_produtos);
    #   - VALORES (base/valor ICMS, IPI, PIS/COFINS base) vem do XML da compra,
    #     rateados pela quantidade e com override manual da tela.
    # montar_imposto (espelho puro do XML) fica como salvaguarda defensiva.
    def imposto_do_item(it)
      regra  = regra_do_item(it)
      fator  = fator_proporcional(it)
      ov     = (it[:imposto_override] || {}).symbolize_keys
      espelho = (it[:imposto] || {}).symbolize_keys

      return montar_imposto(espelho, fator, it[:imposto_override]) if regra.nil?

      montar_imposto_hibrido(regra, espelho, fator, ov)
    end

    # CST/CSOSN da regra + valores do XML (rateados/override). Cobre Simples
    # (CSOSN sem destaque -> valores podem ser zerados pela tela) e regime
    # normal (CST + ICMS/IPI/PIS/COFINS destacados com valor, como no DANFE).
    def montar_imposto_hibrido(regra, espelho, fator, ov)
      icms_x = espelho[:icms] || {}
      ipi_x  = espelho[:ipi] || {}
      pis_x  = espelho[:pis] || {}
      cof_x  = espelho[:cofins] || {}

      out = {}

      # ICMS: codigo da regra (CSOSN no Simples); se a regra nao tiver, usa o
      # CST que veio do XML. Valores e ALIQUOTA sempre editaveis pela tela
      # (override); senao vem da regra; senao do XML.
      out["ICMS"] = {
        "CodSituacaoTributaria" => regra.csosn.presence || icms_x[:cst],
        "AliquotaICMS"          => aliquota_final(ov[:icms_aliquota], regra.aliquota_icms, icms_x[:aliquota]),
        "BaseCalculo"           => valor_final(ov[:icms_base], icms_x[:base_calculo], fator),
        "ValorIcms"             => valor_final(ov[:icms_valor], icms_x[:valor], fator)
      }.compact

      # IPI: CST da regra; valor e aliquota rateados do XML (ou override da tela).
      if regra.cst_ipi.present? || ipi_x[:valor].to_d.nonzero?
        out["IPI"] = {
          "CodSituacaoTributaria" => regra.cst_ipi.presence || ipi_x[:cst],
          "CodEnquadramento"      => regra.cod_enquadramento_ipi.presence || "999",
          "Aliquota"              => aliquota_final(ov[:ipi_aliquota], regra.aliquota_ipi, ipi_x[:aliquota]),
          "ValorIpiDevolvido"     => valor_final(ov[:ipi_valor], ipi_x[:valor], fator),
          "PercentualMercadoriaDevolvida" => 100
        }.compact
      end

      # PIS/COFINS: CST/aliquota da regra; base rateada do XML.
      out["PIS"] = {
        "CodSituacaoTributaria" => regra.cst_pis.presence || pis_x[:cst],
        "Aliquota"              => (regra.aliquota_pis.presence&.to_f) || to_f_or_nil(pis_x[:aliquota]),
        "BaseCalculo"           => ratear(pis_x[:base_calculo], fator)
      }.compact
      out["COFINS"] = {
        "CodSituacaoTributaria" => regra.cst_cofins.presence || cof_x[:cst],
        "Aliquota"              => (regra.aliquota_cofins.presence&.to_f) || to_f_or_nil(cof_x[:aliquota]),
        "BaseCalculo"           => ratear(cof_x[:base_calculo], fator)
      }.compact

      out.reject { |_, v| v.blank? }
    end

    # Resolve a regra fiscal para a operacao de devolucao. Usa o perfil escolhido
    # na linha (it[:cod_perfil_tributario]) com prioridade; senao, o perfil do
    # proprio produto. Memoiza por item para nao reconsultar.
    def regra_do_item(it)
      return nil if @operacao.nil?
      @regra_cache ||= {}
      chave = [it[:cod_produto], it[:cod_perfil_tributario]]
      return @regra_cache[chave] if @regra_cache.key?(chave)

      produto = Produto.find_by(cod_produto: it[:cod_produto])
      perfil  = PerfilTributario.find_by(cod_perfil_tributario: it[:cod_perfil_tributario]) if it[:cod_perfil_tributario].present?
      @regra_cache[chave] = @resolver.regra_para(produto, @operacao, perfil: perfil)
    rescue
      nil
    end

    # Fator de rateio dos impostos quando a devolucao e parcial.
    # Ex: comprou 3, devolve 1 -> fator 1/3. Base/valor dos impostos sao
    # multiplicados por esse fator. Aliquota (percentual) nao muda.
    # Sem quantidade_original (fallback), ou quantidades invalidas -> 1 (cheio).
    def fator_proporcional(it)
      qtd_dev  = it[:quantidade].to_d
      qtd_orig = it[:quantidade_original].to_d
      return 1.to_d if qtd_orig.zero? || qtd_dev.zero?
      return 1.to_d if qtd_dev == qtd_orig
      qtd_dev / qtd_orig
    end

    # CFOP, por ordem de prioridade:
    #   1) CFOP do proprio item (editado na linha) — vence tudo;
    #   2) CFOP geral informado;
    #   3) CFOP da REGRA do perfil PARA A OPERACAO escolhida no topo (por UF).
    # Sem regra para essa operacao, fica EM BRANCO (nil) — nao converte o XML.
    def cfop_do_item(it)
      return it[:cfop].to_s.gsub(/\D/, "").to_i if it[:cfop].present?
      return @cfop.to_i if @cfop.present?
      regra = regra_do_item(it)
      if regra
        c = RegraFiscal.cfop_por_uf(regra.cfop_base, @empresa&.uf, @fornecedor&.uf)
        return c.to_i if c.present?
      end
      nil
    end

    # Converte CFOP de entrada (nota de compra, 1/2/3xxx) para saida (5/6/7xxx).
    def cfop_saida(cfop_entrada)
      c = cfop_entrada.to_s.gsub(/\D/, "")
      return nil if c.length < 4
      mapa = { "1" => "5", "2" => "6", "3" => "7" }
      (mapa[c[0]] || c[0]) + c[1..]
    end

    # Espelha o imposto destacado na entrada para o payload do EnviarNotaFiscal.
    # Usa os VALORES (BaseCalculo/Valor) quando presentes.
    # Espelha o imposto da entrada aplicando o fator de rateio (devolucao parcial).
    # Valores monetarios (BaseCalculo, ValorIcms, ValorIpiDevolvido) sao
    # multiplicados pelo fator; percentuais (aliquota) permanecem.
    def montar_imposto(imp, fator = 1.to_d, override = {})
      return {} if imp.blank?
      imp = imp.symbolize_keys
      ov  = (override || {}).symbolize_keys
      out = {}

      if imp[:icms].present?
        i = imp[:icms]
        out["ICMS"] = {
          "CodSituacaoTributaria" => i[:cst],
          # Override manual (digitado na tela) tem prioridade; senao, do XML.
          "AliquotaICMS"          => aliquota_final(ov[:icms_aliquota], nil, i[:aliquota]),
          "BaseCalculo"           => valor_final(ov[:icms_base], i[:base_calculo], fator),
          "ValorIcms"             => valor_final(ov[:icms_valor], i[:valor], fator)
        }.compact
      end

      if imp[:ipi].present?
        i = imp[:ipi]
        out["IPI"] = {
          "CodSituacaoTributaria"        => i[:cst],
          "Aliquota"                     => aliquota_final(ov[:ipi_aliquota], nil, i[:aliquota]),
          "ValorIpiDevolvido"            => valor_final(ov[:ipi_valor], i[:valor], fator),
          "PercentualMercadoriaDevolvida"=> 100
        }.compact
      end

      if imp[:pis].present?
        i = imp[:pis]
        out["PIS"] = {
          "CodSituacaoTributaria" => i[:cst],
          "Aliquota"              => to_f_or_nil(i[:aliquota]),
          "BaseCalculo"           => ratear(i[:base_calculo], fator)
        }.compact
      end

      if imp[:cofins].present?
        i = imp[:cofins]
        out["COFINS"] = {
          "CodSituacaoTributaria" => i[:cst],
          "Aliquota"              => to_f_or_nil(i[:aliquota]),
          "BaseCalculo"           => ratear(i[:base_calculo], fator)
        }.compact
      end

      out
    end

    # Aplica o fator de rateio a um valor monetario, arredondando a 2 casas.
    # Retorna nil quando zera (compact remove do payload).
    def ratear(valor, fator)
      return nil if valor.nil?
      v = (valor.to_d * fator).round(2)
      v.zero? ? nil : v.to_f
    end

    # Valor final de um campo de imposto: usa o override manual (digitado na
    # tela) quando informado; caso contrario, rateia o valor do XML pelo fator.
    def valor_final(override, bruto, fator)
      return override.to_d.round(2).to_f if override.present?
      ratear(bruto, fator)
    end

    # Aliquota final: override da tela (aceita 0 informado) > regra > XML.
    # O override "" (vazio) significa "nao informado" -> cai na regra/XML.
    # O override "0" significa zerar explicitamente -> retorna 0.0.
    def aliquota_final(override, da_regra, do_xml)
      unless override.nil? || override.to_s.strip.empty?
        return override.to_d.to_f
      end
      return da_regra.to_f if da_regra.present?
      to_f_or_nil(do_xml)
    end

    def montar_pagamentos
      [{
        "IndicadorPagamento" => 0,
        "FormaPagamento"     => "90", # sem pagamento (devolucao)
        "VlPago"             => 0.0
      }]
    end

    def to_f_or_nil(v)
      return nil if v.nil?
      f = v.to_f
      f.zero? ? nil : f
    end

    def digitos(valor)
      valor.to_s.gsub(/\D/, "").presence
    end
  end
end
