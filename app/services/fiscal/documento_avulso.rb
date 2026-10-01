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
  class ItemAvulso
    attr_reader :cod_produto, :cod_cor, :quantidade, :valorunitario

    def initialize(attrs)
      a = attrs.symbolize_keys
      @cod_produto   = a[:cod_produto]
      @cod_cor       = a[:cod_cor]
      @quantidade    = a[:quantidade].to_d
      @valorunitario = a[:valorunitario].to_d
    end

    def produto
      @produto ||= Produto.find_by(cod_produto: @cod_produto)
    end

    def cancelado?
      false
    end
  end
end
