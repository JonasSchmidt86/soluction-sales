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
        # Cabecalho fiscal opcional (nota avulsa): observacoes e NF referenciada.
        # Venda comum nao responde a esses metodos (try => nil) e nada muda.
        info_adicional:       @venda.try(:info_adicional).presence,
        info_adicional_fisco: @venda.try(:info_adicional_fisco).presence,
        # NF referenciada NO CABECALHO so quando NAO e devolucao. Na devolucao
        # (finalidade 4) a referencia vai POR ITEM (ChaveAcessoReferenciada); a
        # doc Brasil NFe diz "em vez do NFReferencia" — mandar nos dois gera a
        # rejeicao "Emitente das NFe Referenciadas deve ser o mesmo".
        nf_referencia:        nf_referencia_cabecalho,
        transporte:           montar_transporte,
        cobranca:             montar_cobranca,
        enviar_email:         false
      }.compact
    end

    # Monta o objeto Transporte (schema Brasil NFe) a partir do hash salvo na
    # nota avulsa (@venda.transporte: modalidade + transportadora[cod_pessoa] +
    # veiculo + volumes). Retorna nil quando nao ha transporte (ou so modalidade
    # 9 = sem frete), para o payload omitir o bloco (default do provedor = 9).
    #
    # Os dados da transportadora vem da PESSOA selecionada (nome/CNPJ/IE/UF/
    # municipio/endereco), nao de campos digitados. Venda comum nao responde a
    # :transporte (try => nil) e nada muda.
    def montar_transporte
      t = @venda.try(:transporte)
      return nil if t.blank?
      t = t.respond_to?(:symbolize_keys) ? t.symbolize_keys : t
      modalidade = t[:modalidade_frete].to_s
      return nil if modalidade.blank? || modalidade == "9"

      bloco = { "ModalidadeFrete" => modalidade.to_i }
      bloco.merge!(dados_transportadora(t[:transportadora_cod_pessoa]))
      veiculo = montar_veiculo(t)
      bloco["Veiculo"] = veiculo if veiculo.present?
      volumes = montar_volumes(t)
      bloco["Volumes"] = volumes if volumes.present?
      bloco
    end

    # Dados da transportadora a partir da Pessoa (cod_pessoa). Vazio se nao houver.
    def dados_transportadora(cod_pessoa)
      return {} if cod_pessoa.blank?
      p = Pessoa.find_by(cod_pessoa: cod_pessoa)
      return {} if p.nil?
      {
        "NmTransportador" => p.nome,
        "CNPJ"            => digitos(p.cpf_cnpj),
        "NmMunicipio"     => p.cidade&.nome,
        "DsEndereco"      => p.endereco,
        "IE"              => p.rg_ie.presence,
        "UF"              => p.uf
      }.compact
    end

    # Veiculo de tracao (Placa/UF/RNTC). nil se nenhum campo preenchido.
    def montar_veiculo(t)
      v = {
        "Placa" => t[:placa].presence,
        "UF"    => t[:placa_uf].presence,
        "RNTC"  => t[:rntc].presence
      }.compact
      v.presence
    end

    # Lista de volumes (um volume). nil se nada preenchido. QuantidadeVolume e
    # inteiro; pesos sao decimais.
    def montar_volumes(t)
      vol = {
        "Numero"           => t[:volume_numero].presence,
        "QuantidadeVolume" => (t[:volume_qtd].presence && t[:volume_qtd].to_i),
        "Especie"          => t[:volume_especie].presence,
        "Marca"            => t[:volume_marca].presence,
        "PesoLiquido"      => (t[:peso_liquido].presence && to_decimal_br(t[:peso_liquido])),
        "PesoBruto"        => (t[:peso_bruto].presence && to_decimal_br(t[:peso_bruto]))
      }.compact
      vol.present? ? [vol] : nil
    end

    # Converte "1.234,5" / "1234.5" para Float (peso). nil se invalido.
    def to_decimal_br(v)
      s = v.to_s.strip.gsub(/\s/, "")
      s = s.gsub(".", "").sub(",", ".") if s.include?(",")
      Float(s)
    rescue ArgumentError
      nil
    end

    private

    # Consumidor final (indFinal). Prioridade: escolha manual da nota avulsa
    # (@venda.consumidor_final_override "sim"/"nao"); senao infere. A escolha
    # manual resolve a rejeicao 696 (PJ NAO contribuinte exige indFinal=1).
    # NFC-e (65) e sempre consumidor final. NF-e (55) infere: consumidor final
    # quando NAO ha destinatario PJ identificado (PF / sem cliente).
    def consumidor_final?
      override = @venda.try(:consumidor_final_override)
      return true  if override == "sim"
      return false if override == "nao"
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
    # IndicadorIe (indIEDest) + Ie: ESSENCIAL para a SEFAZ saber se o
    # destinatario e contribuinte. Sem isso a Brasil NFe assume o default 9
    # (nao contribuinte), o que gera a rejeicao 696 em operacao nao-consumidor
    # final (ex.: devolucao a fornecedor). Cliente com IE valida (rg_ie) =>
    # IndicadorIe 1 (contribuinte) + envia a IE; sem IE => 9 (nao contribuinte).
    def montar_cliente
      return nil if @cliente.blank?

      c = {
        "CpfCnpj"   => digitos(@cliente.cpf_cnpj),
        "NmCliente" => @cliente.nome
      }

      ie = ie_destinatario
      if ie.present?
        c["IndicadorIe"] = 1   # contribuinte ICMS
        c["Ie"]          = ie
      else
        c["IndicadorIe"] = 9   # nao contribuinte (sem IE cadastrada)
      end

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

    # IE do destinatario (campo rg_ie), so digitos. "ISENTO"/vazio => nil (sem IE).
    def ie_destinatario
      bruto = @cliente.rg_ie.to_s.strip
      return nil if bruto.blank? || bruto.casecmp?("ISENTO")
      digitos(bruto)
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
        # Fiscal do produto POR EMPRESA (ncm/cest/origem/gtin/perfil). Com
        # fallback no produto global quando ainda nao ha fiscal_produto.
        fiscal  = FiscalProduto.para(@empresa&.cod_empresa, produto&.cod_produto)
        regra   = regra_para(produto, item, fiscal)

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

        prod = {
          "NmProduto"        => produto&.nome,
          "CodProdutoServico"=> produto&.cod_produto.to_s,
          "EAN"              => fiscal.gtin.presence,
          "NCM"              => fiscal.ncm,
          "CEST"             => fiscal.cest.presence,
          "UnidadeComercial" => produto&.ucom.presence || "UN",
          "Quantidade"       => quantidade.to_f,
          "ValorUnitario"    => valor_unit.to_f,
          "ValorTotal"       => valor_total.to_f,
          "CFOP"             => cfop&.to_i,
          "OrigemProduto"    => (fiscal.origem.presence || "0").to_i,
          "Imposto"          => montar_imposto(regra)
        }

        # Devolucao (finalidade 4): a SEFAZ exige a NF original referenciada
        # POR ITEM (grupo DFeReferenciado), em vez do NFReferencia no cabecalho.
        # Envia so a ChaveAcessoReferenciada. NAO envia NItemReferenciado: a doc
        # diz que e o numero do item na NOTA ORIGINAL (nao nesta devolucao) e e
        # opcional — sem saber o item de origem, omitimos para nao referenciar
        # item errado.
        chave_ref = chave_referenciada_devolucao
        prod["ChaveAcessoReferenciada"] = chave_ref if chave_ref

        prod.compact
      end
    end

    # Chave da NF referenciada SO para devolucao (finalidade 4), usada na
    # referencia por item. Fora da devolucao retorna nil (nao referencia item).
    def chave_referenciada_devolucao
      return nil unless @finalidade.to_i == 4
      Array(@venda.try(:chave_referenciada)).reject(&:blank?).first
    end

    # NFReferencia do CABECALHO: usada quando NAO e devolucao (finalidade != 4).
    # Na devolucao a referencia e por item (ChaveAcessoReferenciada), entao o
    # cabecalho fica vazio para nao duplicar a referencia.
    def nf_referencia_cabecalho
      return nil if @finalidade.to_i == 4
      Array(@venda.try(:chave_referenciada)).reject(&:blank?).presence
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

    # Pagamentos da nota. Quando a nota avulsa informa uma LISTA de pagamentos
    # (@venda.pagamentos: uma ou mais formas), usa ela. Caso contrario, PADRAO:
    # 1 pagamento "99 - Outros" = total liquido da nota (default pedido: no
    # padrao a nota NAO mostra duplicata ao cliente — cobr so vai com forma a
    # prazo informada; 99 so informa a forma, sem duplicatas).
    #
    # IndicadorPagamento: 1 (a prazo) quando ha COBRANCA (duplicatas); senao 0.
    # tPag 90 (sem pagamento): VlPago = 0 (ex.: remessa, devolucao, brinde).
    def montar_pagamentos
      a_prazo = cobranca_valida? ? 1 : 0
      lista = @venda.try(:pagamentos)
      return montar_pagamentos_padrao(a_prazo) if lista.blank?

      Array(lista).map do |p|
        h = p.respond_to?(:symbolize_keys) ? p.symbolize_keys : p
        forma = h[:forma].to_s
        pagamento = {
          "IndicadorPagamento" => a_prazo,
          "FormaPagamento"     => forma,
          "VlPago"             => (forma == "90" ? 0.0 : h[:valor].to_d.to_f)
        }
        # Descricao (xPag): so vai ao XML quando FormaPagamento=99 (doc Brasil NFe).
        # No 99 sem descricao, manda "Outros" (evita rejeicao 441).
        pagamento["Descricao"] = (h[:descricao].presence || "Outros") if forma == "99"
        pagamento
      end
    end

    # Pagamento unico = total liquido da nota, forma "99 - Outros" (default).
    # 99 nao mostra duplicata ao cliente; a descricao "Outros" evita rejeicao 441.
    def montar_pagamentos_padrao(indicador = 0)
      [{
        "IndicadorPagamento" => indicador,
        "FormaPagamento"     => "99",
        "VlPago"             => total_liquido_itens.to_f,
        "Descricao"          => "Outros"
      }]
    end

    # COBRANCA (bloco cobr): fatura + duplicatas com vencimento. So e enviada
    # quando ha parcelas informadas E a forma de pagamento NAO e 99/90 (ou seja,
    # uma forma a prazo real). No default (99) nunca sai duplicata, mesmo que a
    # venda tenha parcelas — conforme decidido. Retorna nil quando nao aplicavel.
    def montar_cobranca
      return nil unless cobranca_valida?
      c = @venda.cobranca
      c = c.respond_to?(:symbolize_keys) ? c.symbolize_keys : c

      parcelas = Array(c[:parcelas]).filter_map do |p|
        pa = p.respond_to?(:symbolize_keys) ? p.symbolize_keys : p
        venc = pa[:vencimento].presence
        valor = pa[:valor].to_d
        next if venc.blank? || valor <= 0
        {
          "Numero"     => pa[:numero].presence,
          "Vencimento" => to_iso_vencimento(venc),
          "Valor"      => valor.to_f
        }.compact
      end
      return nil if parcelas.empty?

      fatura = c[:fatura].is_a?(Hash) ? (c[:fatura].respond_to?(:symbolize_keys) ? c[:fatura].symbolize_keys : c[:fatura]) : {}
      total = parcelas.sum { |x| x["Valor"].to_d }
      {
        "Fatura" => {
          "Numero"       => fatura[:numero].presence,
          "Valor"        => (fatura[:valor].presence && fatura[:valor].to_d.to_f) || total.to_f,
          "Desconto"     => (fatura[:desconto].presence && fatura[:desconto].to_d.to_f),
          "ValorLiquido" => (fatura[:valor_liquido].presence && fatura[:valor_liquido].to_d.to_f) || total.to_f
        }.compact,
        "Parcelas" => parcelas
      }
    end

    # Cobranca so vale quando: ha parcelas E a forma de pagamento informada e a
    # prazo (diferente de 99 "Outros" e 90 "Sem pagamento"). Default 99 => nunca.
    def cobranca_valida?
      c = @venda.try(:cobranca)
      return false if c.blank?
      c = c.respond_to?(:symbolize_keys) ? c.symbolize_keys : c
      return false if Array(c[:parcelas]).empty?

      formas = Array(@venda.try(:pagamentos)).map do |p|
        (p.respond_to?(:symbolize_keys) ? p.symbolize_keys : p)[:forma].to_s
      end
      # Sem forma informada => default 99 => sem duplicata. Com forma, exige que
      # ao menos uma seja a prazo (nao 99/90).
      formas.any? { |f| f.present? && f != "99" && f != "90" }
    end

    # Vencimento no formato date-time ISO -03:00 que a API espera (inicio do dia).
    def to_iso_vencimento(valor)
      d = valor.is_a?(Date) || valor.is_a?(Time) ? valor.to_date : Date.parse(valor.to_s)
      "#{d.strftime('%Y-%m-%d')}T00:00:00-03:00"
    rescue ArgumentError, TypeError
      nil
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
    def regra_para(produto, item = nil, fiscal = nil)
      # Perfil escolhido no item (tela avulsa) tem prioridade; senao, o perfil do
      # fiscal_produto da empresa (com fallback no perfil do produto global).
      # Retrocompativel: itens de venda nao respondem a perfil_tributario_escolhido.
      fiscal ||= FiscalProduto.para(@empresa&.cod_empresa, produto&.cod_produto)
      perfil =
        if item.respond_to?(:perfil_tributario_escolhido)
          item.perfil_tributario_escolhido
        else
          fiscal.perfil_tributario
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
