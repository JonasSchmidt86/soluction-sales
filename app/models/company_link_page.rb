class CompanyLinkPage < ApplicationRecord
  belongs_to :empresa, foreign_key: "empresa_id", primary_key: "cod_empresa"

  # Imagem exibida no topo da página (fachada da loja, logo, etc.)
  has_one_attached :imagem, service: :local_custom

  FORMATOS_IMAGEM = %w[redonda quadrada cabecalho].freeze

  # Atributo virtual: recebe o recorte feito no navegador (Cropper.js) como data URL.
  attr_accessor :imagem_recortada

  has_many :social_links, -> { order(:ordem) }, dependent: :destroy
  accepts_nested_attributes_for :social_links, reject_if: :all_blank, allow_destroy: true # cocoon gem

  # Contatos de WhatsApp publicados da empresa (viram botões na página)
  has_many :whatsapp_contacts,
           -> { where(publicar_link: true).order(:ordem, :id) },
           foreign_key: "empresa_id",
           primary_key: "empresa_id"

  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/,
                             message: "use apenas letras minúsculas, números, hífen ou underline" }
  validates :empresa_id, presence: true, uniqueness: true
  validates :formato_imagem, inclusion: { in: FORMATOS_IMAGEM }

  HEX_REGEX = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/
  validates :cor_fundo_inicio, :cor_fundo_fim, :cor_texto, format: { with: HEX_REGEX,
            message: "deve ser uma cor hexadecimal (ex: #1f2a33)" }, allow_blank: true

  before_validation :normalizar_slug

  scope :publicadas, -> { where(publicado: true) }

  # Título exibido (usa o nome da empresa como fallback)
  def titulo_exibido
    titulo.presence || empresa&.nome
  end

  def imagem_redonda?
    formato_imagem == "redonda"
  end

  # Cores de fundo com fallback para o degradê padrão
  def cor_inicio
    cor_fundo_inicio.presence || "#1f2a33"
  end

  def cor_fim
    cor_fundo_fim.presence || "#343a40"
  end

  # CSS do fundo (degradê). Se as duas cores forem iguais, vira cor sólida.
  def css_fundo
    "linear-gradient(160deg, #{cor_inicio} 0%, #{cor_fim} 100%)"
  end

  def cor_do_texto
    cor_texto.presence || "#ffffff"
  end

  # Processa a imagem enviada (recorta o centro em quadrado 400x400) e anexa.
  # Usado como fallback quando o usuário não fez o recorte manual.
  # Segue o mesmo padrão de resize usado em WhatsappContact.
  def resize_imagem_before_attach(uploaded_io)
    imagem_processada = MiniMagick::Image.read(uploaded_io.tempfile)
    imagem_processada.resize "400x400^"
    imagem_processada.gravity "center"
    imagem_processada.extent "400x400"

    imagem.attach(
      io: StringIO.new(imagem_processada.to_blob),
      filename: "#{slug.presence || 'link'}_#{uploaded_io.original_filename}",
      content_type: uploaded_io.content_type
    )
  end

  # Anexa a imagem já recortada pelo usuário no navegador (Cropper.js).
  # Recebe um data URL base64 (ex: "data:image/png;base64,....").
  def attach_imagem_from_data_url(data_url)
    return if data_url.blank?

    match = data_url.match(/\Adata:(?<tipo>image\/\w+);base64,(?<dados>.+)\z/m)
    return unless match

    binario = Base64.decode64(match[:dados])
    extensao = match[:tipo].split("/").last

    imagem.attach(
      io: StringIO.new(binario),
      filename: "#{slug.presence || 'link'}_recorte.#{extensao}",
      content_type: match[:tipo]
    )
  end

  private

  def normalizar_slug
    base = slug.presence || titulo.presence || empresa&.nome
    return if base.blank?

    self.slug = base.to_s.parameterize(separator: "-")
  end
end
