module Fiscal
  # Transforma uma Venda (+ Perfil Tributario dos produtos + FiscalConfig) no
  # "documento neutro" (Hash) que o BrasilNfeAdapter traduz para o payload.
  #
  # A tributacao vem SEMPRE do Perfil Tributario do nosso sistema (nunca do
  # painel do provedor). O CFOP e resolvido por perfil+operacao+UF (5/6/7 auto).
  #
  # Foco inicial: NFC-e balcao (modelo 65, consumidor final). NF-e (55) reusa
  # a mesma estrutura, mudando modelo/cliente completo.
  #
  # Uso:
  #   doc = Fiscal::DocumentoFiscalBuilder.new(venda, operacao: op, config: cfg).montar
  #   FiscalService.new(cfg).emitir(doc)
  class DocumentoFiscalBuilder
    class DadoFiscalAusente < StandardError; end

    def initialize(venda, operacao:, config: nil, modelo: nil)
      @venda    = venda
      @operacao = operacao          # OperacaoFiscal (ex: "Venda")
      @config   = config
      @modelo   = modelo || 65      # 65 = NFC-e (balcao) por padrao
      @empresa  = venda.empresa
      @cliente  = venda.pessoa
    end

    def montar
      {
        modelo:               @modelo,
        finalidade:           1, # normal
        natureza:             @operacao&.natureza_operacao.presence || "Venda de mercadoria",
        consumidor_final:     true,
        indicador_presenca:   1, # operacao presencial (balcao)
        identificador_interno: "VENDA-#{@venda.cod_venda}",
        cliente:              montar_cliente,
        produtos:             montar_produtos,
        pagamentos:           montar_pagamentos,
        enviar_email:         false
      }.compact
    end

    private

    # UF de origem = empresa emitente. UF de destino = cliente (ou origem se sem cliente).
    def uf_origem
      @empresa&.uf
    end

    def uf_destino
      @cliente&.uf.presence || uf_origem
    end

    # NFC-e consumidor final: cliente e opcional. Se houver, envia dados basicos.
    def montar_cliente
      return nil if @cliente.blank?

      c = {
        "CpfCnpj"   => digitos(@cliente.cpf_cnpj),
        "NmCliente" => @cliente.nome
      }
      if @cliente.uf.present?
        c["Endereco"] = {
          "Cep"         => digitos(@cliente.cep),
          "Logradouro"  => @cliente.endereco,
          "Numero"      => @cliente.numero,
          "Bairro"      => @cliente.bairro,
          "CodMunicipio"=> @cliente.cod_municipio_ibge,
          "Municipio"   => @cliente.cidade&.nome,
          "Uf"          => @cliente.uf
        }.compact
      end
      c.compact
    end

    def montar_produtos
      itens = @venda.itensvenda.reject(&:cancelado?)
      raise DadoFiscalAusente, "Venda sem itens" if itens.empty?

      itens.map do |item|
        produto = item.produto
        regra   = regra_para(produto)

        cfop = RegraFiscal.cfop_por_uf(regra&.cfop_base, uf_origem, uf_destino)

        {
          "NmProduto"        => produto&.nome,
          "CodProdutoServico"=> produto&.cod_produto.to_s,
          "EAN"              => produto&.gtin.presence,
          "NCM"              => produto&.ncm,
          "CEST"             => produto&.cest.presence,
          "UnidadeComercial" => produto&.ucom.presence || "UN",
          "Quantidade"       => item.quantidade.to_f,
          "ValorUnitario"    => item.valorunitario.to_f,
          "ValorTotal"       => (item.quantidade.to_f * item.valorunitario.to_f).round(2),
          "CFOP"             => cfop&.to_i,
          "OrigemProduto"    => (produto&.origem.presence || "0").to_i,
          "Imposto"          => montar_imposto(regra)
        }.compact
      end
    end

    # Imposto por item a partir da regra do perfil. Caso Simples sem ST:
    # ICMS com CSOSN, PIS/COFINS conforme CST da regra.
    def montar_imposto(regra)
      {
        "ICMS" => {
          "CodSituacaoTributaria" => regra&.csosn,
          "AliquotaICMS"          => regra&.aliquota_icms&.to_f
        }.compact,
        "PIS" => {
          "CodSituacaoTributaria" => regra&.cst_pis
        }.compact,
        "COFINS" => {
          "CodSituacaoTributaria" => regra&.cst_cofins
        }.compact
      }.reject { |_, v| v.blank? }
    end

    # Pagamento simples (a vista). Detalhe de parcelas/formas fica para depois.
    def montar_pagamentos
      [{
        "IndicadorPagamento" => 0,   # a vista
        "FormaPagamento"     => "99", # outros (ajustar quando mapear formas reais)
        "VlPago"             => @venda.valortotal.to_f
      }]
    end

    # Encontra a regra do perfil do produto que casa com a operacao atual.
    # Prioriza a regra especifica (maior prioridade) e cai na padrao (uf "*").
    def regra_para(produto)
      perfil = produto&.perfil_tributario
      return nil if perfil.nil? || @operacao.nil?

      candidatas = perfil.regras.select do |r|
        r.cod_operacao_fiscal == @operacao.cod_operacao_fiscal && r.ativo
      end
      # match por UF destino exata; senao curinga "*"
      candidatas.select { |r| [uf_destino, "*"].include?(r.uf_destino) }
                .max_by { |r| [r.uf_destino == uf_destino ? 1 : 0, r.prioridade.to_i] }
    end

    def digitos(valor)
      valor.to_s.gsub(/\D/, "").presence
    end
  end
end
