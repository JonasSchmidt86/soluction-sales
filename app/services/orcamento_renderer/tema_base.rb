# frozen_string_literal: true

module OrcamentoRenderer
  class TemaBase
    def name
      raise NotImplementedError
    end

    def tema_partial
      "collaborators_backoffice/orcamento_renderer/temas/#{name}"
    end

    def dimensoes_foto
      { "small" => "120px", "medium" => "180px", "large" => "260px" }
    end

    def estilos_documento(orcamento)
      { font_family: "'Segoe UI', system-ui, sans-serif", line_height: "1.6",
        background: "#ffffff", color: "#333333" }
    end

    def estilos_header(orcamento)
      { background: orcamento.cor_primaria, color: "#ffffff", padding: "2.5rem 3rem",
        line_color: "rgba(255,255,255,0.35)", muted_color: "rgba(255,255,255,0.85)",
        logo_invert: false }
    end

    def estilos_produto(orcamento)
      { margin_bottom: "2rem", padding: "0", background: "transparent",
        border: "none", border_radius: "0" }
    end

    def estilos_footer(orcamento)
      { background: orcamento.cor_primaria, color: "rgba(255,255,255,.7)", padding: "1.2rem 3rem",
        line_color: "rgba(255,255,255,0.35)", muted_color: "rgba(255,255,255,0.8)" }
    end
  end
end
