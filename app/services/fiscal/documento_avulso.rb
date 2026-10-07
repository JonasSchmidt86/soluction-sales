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
    attr_reader :empresa, :pessoa

    def initialize(empresa:, itens:, cliente: nil)
      @empresa = empresa
      @pessoa  = cliente
      @itens   = Array(itens).map { |h| ItemAvulso.new(h) }
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

    def initialize(attrs)
      a = attrs.symbolize_keys
      @cod_produto   = a[:cod_produto]
      @cod_cor       = a[:cod_cor]
      @quantidade    = a[:quantidade].to_d
      @valorunitario = a[:valorunitario].to_d
      @cod_perfil_tributario = a[:cod_perfil_tributario].presence
      @cfop                  = a[:cfop].presence
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

    # Perfil escolhido na tela (prioridade) ou o perfil do proprio produto.
    def perfil_tributario_escolhido
      if @cod_perfil_tributario
        PerfilTributario.find_by(cod_perfil_tributario: @cod_perfil_tributario)
      else
        produto&.perfil_tributario
      end
    end

    def cancelado?
      false
    end
  end
end
