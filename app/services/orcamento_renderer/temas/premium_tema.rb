# frozen_string_literal: true

module OrcamentoRenderer
  module Temas
    class PremiumTema < TemaBase
      def name = "premium"

      def dimensoes_foto
        { "small" => "140px", "medium" => "200px", "large" => "300px" }
      end

      def estilos_header(orcamento)
        { background: "#ffffff", color: orcamento.cor_primaria,
          padding: "3rem 2.5rem 2rem",
          line_color: "rgba(44,44,44,0.12)", muted_color: "rgba(44,44,44,0.75)",
          logo_invert: false }
      end

      def estilos_produto(orcamento)
        { margin_bottom: "2.5rem", padding: "0 0 2.5rem 0", background: "transparent",
          border: "none", border_bottom: "1px solid #f0f0f0", border_radius: "0" }
      end

      def estilos_footer(orcamento)
        { background: "#fafafa", color: "#999999", padding: "1.8rem 2.5rem",
          border_top: "1px solid #f0f0f0",
          line_color: "rgba(44,44,44,0.12)", muted_color: "rgba(44,44,44,0.7)" }
      end
    end
  end
end
