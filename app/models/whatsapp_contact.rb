class WhatsappContact < ApplicationRecord
  belongs_to :empresa, foreign_key: 'empresa_id', primary_key: 'cod_empresa'
  belongs_to :funcionario, foreign_key: 'funcionario_id', primary_key: 'cod_funcionario'

  has_one_attached :photo, service: :local_custom

  validates :whatsapp_number, presence: true

  delegate :nome, to: :funcionario, prefix: true
  delegate :nome, to: :empresa, prefix: true

  scope :publicados, -> { where(publicar_link: true).order(:ordem, :id) }

  # Monta a URL do WhatsApp a partir do número cadastrado.
  # Ex: "(45)99996-7722" => "https://wa.me/5545999967722?text=..."
  def whatsapp_url(mensagem = nil)
    digitos = whatsapp_number.to_s.gsub(/\D/, "")
    return nil if digitos.blank?

    # Garante o código do país (Brasil = 55) quando ausente
    digitos = "55#{digitos}" unless digitos.start_with?("55")

    url = "https://wa.me/#{digitos}"
    url += "?text=#{CGI.escape(mensagem)}" if mensagem.present?
    url
  end

  def resize_photo_before_attach(uploaded_io)
    puts "=-------------------------------------------="
    puts "NOME DA IMAGEM: #{uploaded_io.original_filename}"
    nome_imagem = "#{display_name.parameterize}_#{uploaded_io.original_filename}"

    
    puts "NOME DA IMAGEM: #{nome_imagem}"
    puts "NOME DA IMAGEM: #{nome_imagem}"
    puts "NOME DA IMAGEM: #{nome_imagem}"
    imagem_processada = MiniMagick::Image.read(uploaded_io.tempfile)
    imagem_processada.resize "300x300" # ajuste o tamanho desejado

    # Anexa a imagem processada
    photo.attach(
      io: StringIO.new(imagem_processada.to_blob),
      filename: nome_imagem,
      content_type: uploaded_io.content_type
    )
  end

end
