# frozen_string_literal: true

module OrcamentoRenderer
  module Temas
    class ExecutivoTema < TemaBase
      def name = "executivo"

      def dimensoes_foto
        { "small" => "130px", "medium" => "190px", "large" => "280px" }
      end

      def estilos_header(orcamento)
        { background: orcamento.cor_primaria, color: "#ffffff", padding: "2.8rem 2.5rem",
          line_color: "rgba(255,255,255,0.35)", muted_color: "rgba(255,255,255,0.85)",
          logo_invert: true }
      end

      def estilos_produto(orcamento)
        { margin_bottom: "2.2rem", padding: "0 0 2.2rem 0", background: "transparent",
          border: "none", border_bottom: "1px solid #eaeaea", border_radius: "0" }
      end

      def estilos_footer(orcamento)
        { background: orcamento.cor_primaria, color: "rgba(255,255,255,.7)", padding: "1.5rem 2.5rem",
          line_color: "rgba(255,255,255,0.35)", muted_color: "rgba(255,255,255,0.8)" }
      end
    end
  end
end
