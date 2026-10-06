module Fiscal
  # Resolve o CFOP de um item a partir da REGRA FISCAL do perfil tributario do
  # produto, para uma dada operacao (ex.: "Devolucao de compra"). Mesma logica
  # de resolucao usada na venda (perfil + operacao + UF destino + tipo cliente),
  # com UF de destino = UF do fornecedor e tipo de cliente = contribuinte
  # (devolucao e sempre entre empresas / PJ).
  #
  # Uso:
  #   Fiscal::CfopResolver.new(empresa: empresa, destino_uf: fornecedor.uf)
  #     .cfop(produto, operacao)   # => 5202 / 6202 ... ou nil se nao houver regra
  class CfopResolver
    def initialize(empresa:, destino_uf:, tipo_cliente: "contribuinte")
      @empresa      = empresa
      @uf_origem    = empresa&.uf
      @uf_destino   = destino_uf.presence || @uf_origem
      @tipo_cliente = tipo_cliente
    end

    # CFOP completo (5/6/7 + base) resolvido pela regra; nil se nao houver regra.
    # perfil: quando informado, usa esse perfil (escolhido na tela); senao, usa
    # o perfil tributario do proprio produto.
    def cfop(produto, operacao, perfil: nil)
      regra = regra_para(produto, operacao, perfil: perfil)
      return nil if regra.nil?
      RegraFiscal.cfop_por_uf(regra.cfop_base, @uf_origem, @uf_destino)
    end

    # Regra do perfil que casa com a operacao + UF destino + tipo cliente.
    # Especifico vence curinga (mesma pontuacao do DocumentoFiscalBuilder).
    def regra_para(produto, operacao, perfil: nil)
      perfil ||= produto&.perfil_tributario
      return nil if perfil.nil? || operacao.nil?

      candidatas = perfil.regras.select do |r|
        r.cod_operacao_fiscal == operacao.cod_operacao_fiscal && r.ativo &&
          [@uf_destino, "*"].include?(r.uf_destino) &&
          [@tipo_cliente, "*"].include?(r.tipo_cliente)
      end

      candidatas.max_by do |r|
        [
          r.uf_destino == @uf_destino ? 1 : 0,
          r.tipo_cliente == @tipo_cliente ? 1 : 0,
          r.prioridade.to_i
        ]
      end
    end
  end
end
