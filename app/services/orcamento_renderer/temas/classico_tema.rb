# frozen_string_literal: true

module OrcamentoRenderer
  module Temas
    class ClassicoTema < TemaBase
      def name = "classico"

      def dimensoes_foto
        { "small" => "120px", "medium" => "180px", "large" => "260px" }
      end

      def estilos_header(orcamento)
        { background: "#ffffff", color: orcamento.cor_primaria,
          padding: "2.5rem 2.5rem 1.8rem", border_bottom: "1px solid #e8e8e8",
          line_color: "rgba(44,44,44,0.15)", muted_color: "rgba(44,44,44,0.75)",
          logo_invert: false }
      end

      def estilos_produto(orcamento)
        { margin_bottom: "1.8rem", padding: "1.5rem", background: "#fafafa",
          border: "none", border_left: "3px solid #{orcamento.cor_destaque}",
          border_radius: "4px" }
      end

      def estilos_footer(orcamento)
        { background: "#ffffff", color: "#aaaaaa", padding: "1.5rem 2.5rem",
          border_top: "1px solid #eee",
          line_color: "rgba(44,44,44,0.15)", muted_color: "rgba(44,44,44,0.75)" }
      end
    end
  end
end
