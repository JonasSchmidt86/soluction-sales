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

    def initialize(venda, operacao:, config: nil, modelo: nil, finalidade: 1)
      @venda    = venda
      @operacao = operacao          # OperacaoFiscal (ex: "Venda")
      @config   = config
      @modelo   = modelo || 65      # 65 = NFC-e (balcao) por padrao
      @finalidade = (finalidade.presence && finalidade.to_i) || 1
      @empresa  = venda.empresa
      @cliente  = venda.pessoa
    end

    # Itens para controle de ESTOQUE FISCAL (qtdfiscal): cada item com a regra
    # resolvida indica se controla estoque. Usado pelo EstoqueFiscalService após
    # a autorização da NF. Reusa a mesma resolução de regra do montar.
    def itens_estoque_fiscal
      @venda.itensvenda.reject(&:cancelado?).map do |item|
        regra = regra_para(item.produto, item)
        {
          cod_produto:      item.cod_produto,
          cod_cor:          item.cod_cor,
          quantidade:       item.quantidade.to_d,
          controla_estoque: (regra&.controla_estoque || "proprio")
        }
      end
    end

    def montar
      {
        modelo:               @modelo,
        finalidade:           @finalidade,
        natureza:             @operacao&.natureza_operacao.presence || "Venda de mercadoria",
        consumidor_final:     consumidor_final?,
        indicador_presenca:   1, # operacao presencial (balcao)
        identificador_interno: identificador_interno,
        cliente:              montar_cliente,
        produtos:             montar_produtos,
        pagamentos:           montar_pagamentos,
        enviar_email:         false
      }.compact
    end

    private

    # NFC-e (65) e sempre consumidor final. NF-e (55) e consumidor final quando
    # NAO ha destinatario PJ identificado (pessoa fisica / sem cliente).
    def consumidor_final?
      return true if @modelo.to_i == 65
      !(@cliente&.pessoa_juridica?)
    end

    # Identificador interno: referencia a venda quando existe; senao, avulso.
    def identificador_interno
      cod = @venda.cod_venda
      cod.present? ? "VENDA-#{cod}" : "AVULSO-#{Time.current.to_i}"
    end

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

      # Rateio do acrescimo/desconto de CABECALHO da venda (venda.acrescimo /
      # venda.desconto) entre os itens. O acrescimo/desconto POR ITEM
      # (item.valor_total) ja vem embutido no total de cada item. Assim o total
      # da nota (soma dos itens) fecha com venda.valortotal e com o pagamento,
      # evitando a rejeicao "ausencia de troco" (pagamento > total da nota).
      ajustes = ratear_ajuste_cabecalho(itens)

      itens.each_with_index.map do |item, idx|
        produto = item.produto
        regra   = regra_para(produto, item)

        # CFOP: override do item (escolhido na tela, ex. avulsa) vence; senao,
        # resolve pela regra por UF. Itens de venda nao tem override -> regra.
        cfop =
          if item.respond_to?(:cfop) && item.cfop.present?
            item.cfop.to_s.gsub(/\D/, "").to_i
          else
            RegraFiscal.cfop_por_uf(regra&.cfop_base, uf_origem, uf_destino)
          end

        quantidade  = item.quantidade.to_d
        # Total liquido do item: subtotal + acrescimo_item - desconto_item
        # (item.valor_total) + a parcela do ajuste de cabecalho rateada nele.
        valor_total = (item.valor_total.to_d + ajustes[idx]).round(2)
        # Preco unitario coerente com o total (SEFAZ valida unitario*qtd ~ total).
        valor_unit  = quantidade.nonzero? ? (valor_total / quantidade).round(10) : valor_total

        {
          "NmProduto"        => produto&.nome,
          "CodProdutoServico"=> produto&.cod_produto.to_s,
          "EAN"              => produto&.gtin.presence,
          "NCM"              => produto&.ncm,
          "CEST"             => produto&.cest.presence,
          "UnidadeComercial" => produto&.ucom.presence || "UN",
          "Quantidade"       => quantidade.to_f,
          "ValorUnitario"    => valor_unit.to_f,
          "ValorTotal"       => valor_total.to_f,
          "CFOP"             => cfop&.to_i,
          "OrigemProduto"    => (produto&.origem.presence || "0").to_i,
          "Imposto"          => montar_imposto(regra)
        }.compact
      end
    end

    # Rateia o acrescimo/desconto de CABECALHO da venda (ajuste = acrescimo -
    # desconto) entre os itens, proporcional ao valor_total de cada item.
    # Retorna um array de BigDecimal (um por item, na ordem) somando exatamente
    # o ajuste; o residuo de centavos vai para o ultimo item. Sem ajuste de
    # cabecalho (ex.: nota avulsa, ou venda sem acrescimo/desconto), retorna
    # zeros e nada muda no total dos itens.
    def ratear_ajuste_cabecalho(itens)
      zeros  = Array.new(itens.size, BigDecimal("0"))
      ajuste = (@venda.try(:acrescimo).to_d - @venda.try(:desconto).to_d)
      return zeros if ajuste.zero?

      base = itens.sum { |i| i.valor_total.to_d }
      return zeros if base.zero?

      acumulado = BigDecimal("0")
      itens.each_with_index.map do |item, idx|
        if idx == itens.size - 1
          (ajuste - acumulado).round(2) # ultimo absorve o residuo de centavos
        else
          parcela = (ajuste * (item.valor_total.to_d / base)).round(2)
          acumulado += parcela
          parcela
        end
      end
    end

    # Imposto por item a partir da regra do perfil. Caso Simples sem ST:
    # ICMS com CSOSN, PIS/COFINS conforme CST da regra. IPI so se houver CST.
    def montar_imposto(regra)
      imposto = {
        "ICMS" => {
          "CodSituacaoTributaria" => regra&.csosn,
          "AliquotaICMS"          => regra&.aliquota_icms&.to_f
        }.compact,
        "PIS" => {
          "CodSituacaoTributaria" => regra&.cst_pis,
          "Aliquota"              => regra&.aliquota_pis&.to_f
        }.compact,
        "COFINS" => {
          "CodSituacaoTributaria" => regra&.cst_cofins,
          "Aliquota"              => regra&.aliquota_cofins&.to_f
        }.compact
      }

      # IPI: so inclui se a regra tiver CST de IPI (revenda Simples geralmente nao tem).
      if regra&.cst_ipi.present?
        imposto["IPI"] = {
          "CodSituacaoTributaria" => regra.cst_ipi,
          "CodEnquadramento"      => regra.cod_enquadramento_ipi.presence || "999",
          "Aliquota"              => regra.aliquota_ipi&.to_f
        }.compact
      end

      imposto.reject { |_, v| v.blank? }
    end

    # Pagamento simples (a vista). Detalhe de parcelas/formas fica para depois.
    # VlPago = total LIQUIDO da nota = soma dos ValorTotal dos itens (ja com
    # acrescimo/desconto do item e o rateio do ajuste de cabecalho). Usar a
    # mesma base dos itens garante VlPago == total da nota e evita a rejeicao
    # "ausencia de troco" (pagamento maior que o total da nota).
    def montar_pagamentos
      [{
        "IndicadorPagamento" => 0,   # a vista
        "FormaPagamento"     => "99", # outros (ajustar quando mapear formas reais)
        "VlPago"             => total_liquido_itens.to_f
      }]
    end

    # Soma dos ValorTotal liquidos dos itens (base unica para VlPago e para o
    # total da nota). Equivale a venda.valortotal, mas calculado a partir dos
    # mesmos numeros ja arredondados dos itens, evitando divergencia de centavos.
    def total_liquido_itens
      itens = @venda.itensvenda.reject(&:cancelado?)
      ajustes = ratear_ajuste_cabecalho(itens)
      itens.each_with_index
           .map { |item, idx| (item.valor_total.to_d + ajustes[idx]).round(2) }
           .sum
    end

    # Encontra a regra do perfil que casa com a operacao + UF destino + tipo cliente.
    # Cada criterio aceita curinga "*". Match exato pontua mais que curinga, e
    # a prioridade da regra desempata. Assim "especifico vence generico".
    #   Ex.: regra (uf=PR, cliente=consumidor_final) vence regra (uf=*, cliente=*)
    #   para um consumidor final do PR; para um cliente de SC, cai na (uf=*).
    def regra_para(produto, item = nil)
      # Perfil escolhido no item (tela avulsa) tem prioridade; senao, o perfil do
      # proprio produto (comportamento da venda). Retrocompativel: itens de venda
      # nao respondem a perfil_tributario_escolhido -> cai no perfil do produto.
      perfil =
        if item.respond_to?(:perfil_tributario_escolhido)
          item.perfil_tributario_escolhido
        else
          produto&.perfil_tributario
        end
      return nil if perfil.nil? || @operacao.nil?

      tipo = tipo_cliente_atual

      candidatas = perfil.regras.select do |r|
        r.cod_operacao_fiscal == @operacao.cod_operacao_fiscal && r.ativo &&
          [uf_destino, "*"].include?(r.uf_destino) &&
          [tipo, "*"].include?(r.tipo_cliente)
      end

      candidatas.max_by do |r|
        [
          r.uf_destino == uf_destino ? 1 : 0,     # UF exata > curinga
          r.tipo_cliente == tipo ? 1 : 0,         # cliente exato > curinga
          r.prioridade.to_i                       # desempate manual
        ]
      end
    end

    # Tipo de cliente da operacao, para casar com tipo_cliente da regra.
    def tipo_cliente_atual
      return "consumidor_final" if @cliente.blank?       # balcao sem identificacao
      @cliente.pessoa_juridica? ? "contribuinte" : "consumidor_final"
    end

    def digitos(valor)
      valor.to_s.gsub(/\D/, "").presence
    end
  end
end
