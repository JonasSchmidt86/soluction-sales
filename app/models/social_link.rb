class SocialLink < ApplicationRecord
  belongs_to :company_link_page

  validates :url, presence: true
  validates :tipo, presence: true

  scope :ativos, -> { where(ativo: true).order(:ordem, :id) }

  # Tipos conhecidos: usados para escolher ícone e cor na página pública.
  # Um tipo novo pode ser cadastrado a qualquer momento sem alterar o banco;
  # se não estiver mapeado, cai no visual padrão de "link".
  TIPOS = {
    "instagram" => { label: "Instagram", icon: "fab fa-instagram",  cor: "linear-gradient(45deg, #f09433, #dc2743, #bc1888)" },
    "facebook"  => { label: "Facebook",  icon: "fab fa-facebook-f", cor: "#1877f2" },
    "site"      => { label: "Site",      icon: "fas fa-globe",      cor: "#17a2b8" },
    "maps"      => { label: "Localização", icon: "fas fa-map-marker-alt", cor: "#ea4335" },
    "tiktok"    => { label: "TikTok",    icon: "fab fa-tiktok",     cor: "#000000" },
    "youtube"   => { label: "YouTube",   icon: "fab fa-youtube",    cor: "#ff0000" },
    "email"     => { label: "E-mail",    icon: "fas fa-envelope",   cor: "#6c757d" },
    "telefone"  => { label: "Telefone",  icon: "fas fa-phone",      cor: "#0d6efd" },
    "outro"     => { label: "Link",      icon: "fas fa-link",       cor: "#495057" }
  }.freeze

  def self.tipos_para_select
    TIPOS.map { |chave, dados| [dados[:label], chave] }
  end

  def config
    TIPOS[tipo] || TIPOS["outro"]
  end

  def icon
    config[:icon]
  end

  def cor
    config[:cor]
  end

  # Texto do botão (usa o label do tipo como fallback)
  def label
    titulo.presence || config[:label]
  end
end
