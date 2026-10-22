module Fiscal
  # Fonte NEUTRA de dados para emissão AVULSA (sem Venda). Expõe a MESMA
  # interface que o DocumentoFiscalBuilder/EmissorFiscal esperam de uma Venda
  # (duck typing), para reaproveitar todo o fluxo de emissão sem alterá-lo.
  #
  # Uso:
  #   avulso = Fiscal::DocumentoAvulso.new(
  #     empresa: empresa, cliente: pessoa_ou_nil,
  #     itens: [{ cod_produto:, cod_cor:, quantidade:, valorunitario: }, ...]
  #   )
  #   Fiscal::EmissorFiscal.new(avulso, modelo: 55, cod_funcionario: 1).emitir
  #
  # NF avulsa é 100% fiscal: não gera Venda nem itemvenda; cod_venda = nil.
  class DocumentoAvulso
    attr_reader :empresa, :pessoa,
                :info_adicional, :info_adicional_fisco,
                :pagamentos, :transporte, :cobranca, :chave_referenciada,
                :consumidor_final_override

    # pagamentos: lista opcional de { forma:, valor:, descricao: } (uma ou mais
    # formas, como no painel Brasil NFe). Vazia = o builder usa o padrao (1
    # pagamento = total da nota).
    # transporte: hash opcional (modalidade/transportadora/volumes).
    # cobranca: hash opcional { fatura: {...}, parcelas: [{numero,vencimento,valor}] }
    # (duplicatas a prazo; so vai ao provedor quando a forma e a prazo).
    # consumidor_final: "sim"/"nao"/nil. nil = automatico (inferido pelo builder).
    def initialize(empresa:, itens:, cliente: nil,
                   info_adicional: nil, info_adicional_fisco: nil,
                   pagamentos: nil, transporte: nil, cobranca: nil,
                   chave_referenciada: nil, consumidor_final: nil)
      @empresa = empresa
      @pessoa  = cliente
      cf = consumidor_final.to_s.strip.downcase
      @consumidor_final_override = (cf if %w[sim nao].include?(cf))
      # Passa o cod_empresa para cada item resolver o perfil via fiscal_produto.
      @itens   = Array(itens).map { |h| ItemAvulso.new(h, cod_empresa: empresa&.cod_empresa) }
      # Cabecalho fiscal opcional (lido pelo DocumentoFiscalBuilder via duck typing).
      @info_adicional       = info_adicional.presence
      @info_adicional_fisco = info_adicional_fisco.presence
      @pagamentos           = normalizar_pagamentos(pagamentos)
      @transporte           = transporte.presence
      @cobranca             = cobranca.presence
      @chave_referenciada   = chave_referenciada.to_s.gsub(/\D/, "").presence
    end

    private

    # Normaliza a lista de pagamentos vinda do form/documento para
    # [{ forma:, valor:, descricao: }], descartando linhas sem forma ou valor<=0.
    # Retorna nil quando nao ha nenhum pagamento valido (builder usa o padrao).
    def normalizar_pagamentos(lista)
      itens = Array(lista).filter_map do |p|
        h = p.respond_to?(:symbolize_keys) ? p.symbolize_keys : p
        forma = h[:forma].to_s.strip
        valor = h[:valor].to_d
        next if forma.blank? || valor <= 0
        { forma: forma, valor: valor, descricao: h[:descricao].to_s.strip.presence }
      end
      itens.presence
    end

    public

    # Interface compatível com Venda:
    def cod_venda
      nil
    end

    def itensvenda
      @itens
    end

    def valortotal
      @itens.sum { |i| i.quantidade.to_d * i.valorunitario.to_d }
    end
  end

  # Item neutro compatível com Itemvenda (para builder/estoque fiscal).
  # Alem dos campos de venda, aceita (opcional) o PERFIL escolhido na tela e um
  # CFOP override — usados na emissao avulsa no modelo da devolucao (perfil +
  # operacao do topo resolvem CFOP/CST). Itens de venda nao informam esses
  # campos, entao o comportamento antigo (perfil do produto) e preservado.
  class ItemAvulso
    attr_reader :cod_produto, :cod_cor, :quantidade, :valorunitario,
                :cod_perfil_tributario, :cfop

    def initialize(attrs, cod_empresa: nil)
      a = attrs.symbolize_keys
      @cod_produto   = a[:cod_produto]
      @cod_cor       = a[:cod_cor]
      @quantidade    = a[:quantidade].to_d
      @valorunitario = a[:valorunitario].to_d
      @cod_perfil_tributario = a[:cod_perfil_tributario].presence
      @cfop                  = a[:cfop].presence
      @cod_empresa           = cod_empresa
    end

    def produto
      @produto ||= Produto.find_by(cod_produto: @cod_produto)
    end

    # NF avulsa nao tem acrescimo/desconto por item: o total e o subtotal puro.
    # Mantem a mesma interface do Itemvenda para o DocumentoFiscalBuilder.
    def valor_acrescimo
      BigDecimal("0")
    end

    def valor_desconto
      BigDecimal("0")
    end

    def valor_total
      (@quantidade.to_d * @valorunitario.to_d)
    end

    # Perfil escolhido na tela (prioridade) ou o da fiscal_produto da empresa
    # (com fallback no produto global via FiscalProduto.para).
    def perfil_tributario_escolhido
      if @cod_perfil_tributario
        PerfilTributario.find_by(cod_perfil_tributario: @cod_perfil_tributario)
      else
        FiscalProduto.para(@cod_empresa, @cod_produto).perfil_tributario
      end
    end

    def cancelado?
      false
    end
  end
end
