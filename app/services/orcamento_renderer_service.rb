# frozen_string_literal: true

module OrcamentoRenderer
  class TemaRegistry
    TEMAS = {
      "premium"   => Temas::PremiumTema,
      "classico"  => Temas::ClassicoTema,
      "executivo" => Temas::ExecutivoTema
    }.freeze

    def self.resolve(name)
      klass = TEMAS[name.to_s]
      (klass || TEMAS["premium"]).new
    end
  end
end

# Service principal
class OrcamentoRendererService
  attr_reader :orcamento, :tema, :itens

  def initialize(orcamento)
    @orcamento = orcamento
    @tema      = OrcamentoRenderer::TemaRegistry.resolve(orcamento.tema)
    @itens     = orcamento.itens_orcamentos.includes(:produto, :cor).order(:posicao_ordem)
  end

  def locals
    { orcamento: orcamento, tema: tema, itens: itens }
  end
end
