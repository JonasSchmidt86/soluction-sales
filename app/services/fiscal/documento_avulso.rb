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
                :forma_pagamento, :descricao_pagamento, :chave_referenciada

    def initialize(empresa:, itens:, cliente: nil,
                   info_adicional: nil, info_adicional_fisco: nil,
                   forma_pagamento: nil, descricao_pagamento: nil,
                   chave_referenciada: nil)
      @empresa = empresa
      @pessoa  = cliente
      # Passa o cod_empresa para cada item resolver o perfil via fiscal_produto.
      @itens   = Array(itens).map { |h| ItemAvulso.new(h, cod_empresa: empresa&.cod_empresa) }
      # Cabecalho fiscal opcional (lido pelo DocumentoFiscalBuilder via duck typing).
      @info_adicional       = info_adicional.presence
      @info_adicional_fisco = info_adicional_fisco.presence
      @forma_pagamento      = forma_pagamento.presence
      @descricao_pagamento  = descricao_pagamento.presence
      @chave_referenciada   = chave_referenciada.to_s.gsub(/\D/, "").presence
    end

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
