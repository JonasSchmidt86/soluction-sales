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
                   natureza_operacao: "Devolucao de compra", cfop: nil, modelo: 55)
      @compra    = compra
      @config    = config
      @itens     = Array(itens)
      @chave_ref = chave_referencia
      @natureza  = natureza_operacao
      @cfop      = cfop
      @modelo    = modelo
      @empresa   = compra.empresa
      @fornecedor = compra.pessoa
    end

    def montar
      {
        modelo:               @modelo,
        finalidade:           4, # Devolucao
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
          "Imposto"          => montar_imposto(it[:imposto])
        }.compact
      end
    end

    # CFOP: o escolhido na tela (mesmo para todos) tem prioridade; senao, o CFOP
    # original da compra convertido para saida (1xxx->5xxx, 2xxx->6xxx).
    def cfop_do_item(it)
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
    def montar_imposto(imp)
      return {} if imp.blank?
      imp = imp.symbolize_keys
      out = {}

      if imp[:icms].present?
        i = imp[:icms]
        out["ICMS"] = {
          "CodSituacaoTributaria" => i[:cst],
          "AliquotaICMS"          => to_f_or_nil(i[:aliquota]),
          "BaseCalculo"           => to_f_or_nil(i[:base_calculo]),
          "ValorIcms"             => to_f_or_nil(i[:valor])
        }.compact
      end

      if imp[:ipi].present?
        i = imp[:ipi]
        out["IPI"] = {
          "CodSituacaoTributaria"        => i[:cst],
          "Aliquota"                     => to_f_or_nil(i[:aliquota]),
          "ValorIpiDevolvido"            => to_f_or_nil(i[:valor]),
          "PercentualMercadoriaDevolvida"=> 100
        }.compact
      end

      if imp[:pis].present?
        i = imp[:pis]
        out["PIS"] = {
          "CodSituacaoTributaria" => i[:cst],
          "Aliquota"              => to_f_or_nil(i[:aliquota]),
          "BaseCalculo"           => to_f_or_nil(i[:base_calculo])
        }.compact
      end

      if imp[:cofins].present?
        i = imp[:cofins]
        out["COFINS"] = {
          "CodSituacaoTributaria" => i[:cst],
          "Aliquota"              => to_f_or_nil(i[:aliquota]),
          "BaseCalculo"           => to_f_or_nil(i[:base_calculo])
        }.compact
      end

      out
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
