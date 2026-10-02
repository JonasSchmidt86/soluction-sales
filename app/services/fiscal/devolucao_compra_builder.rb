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
                   finalidade: 4)
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
    end

    def montar
      {
        modelo:               @modelo,
        finalidade:           @finalidade,
        natureza:             @natureza.presence || "Devolucao de compra",
        consumidor_final:     false,
        indicador_presenca:   0, # nao se aplica (operacao entre empresas)
        identificador_interno: "DEVCOMPRA-#{@compra.cod_compra}",
        nf_referencia:        Array(@chave_ref).reject(&:blank?),
        cliente:              montar_fornecedor,
        produtos:             montar_produtos,
        pagamentos:           montar_pagamentos,
        enviar_email:         false
      }.compact
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
      {
        "CpfCnpj"   => digitos(@fornecedor.cpf_cnpj),
        "NmCliente" => @fornecedor.nome,
        "Ie"        => @fornecedor.rg_ie.presence,
        "Endereco"  => endereco_fornecedor
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
          "Imposto"          => montar_imposto(it[:imposto], fator_proporcional(it), it[:imposto_override])
        }.compact
      end
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
    #   2) CFOP geral escolhido na tela (operacao) — padrao para todos;
    #   3) CFOP original da compra convertido para saida (1xxx->5xxx, 2xxx->6xxx).
    def cfop_do_item(it)
      return it[:cfop].to_s.gsub(/\D/, "").to_i if it[:cfop].present?
      return @cfop.to_i if @cfop.present?
      cfop_saida(it[:cfop_original])
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
          "AliquotaICMS"          => to_f_or_nil(i[:aliquota]),
          # Override manual (digitado na tela) tem prioridade; senao, rateia.
          "BaseCalculo"           => valor_final(ov[:icms_base], i[:base_calculo], fator),
          "ValorIcms"             => valor_final(ov[:icms_valor], i[:valor], fator)
        }.compact
      end

      if imp[:ipi].present?
        i = imp[:ipi]
        out["IPI"] = {
          "CodSituacaoTributaria"        => i[:cst],
          "Aliquota"                     => to_f_or_nil(i[:aliquota]),
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
