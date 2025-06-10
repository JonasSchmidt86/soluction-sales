class WhatsappContact < ApplicationRecord
  belongs_to :empresa, foreign_key: 'empresa_id', primary_key: 'cod_empresa'
  belongs_to :funcionario, foreign_key: 'funcionario_id', primary_key: 'cod_funcionario'

  has_one_attached :photo, service: :local_custom

  validates :whatsapp_number, presence: true

  delegate :nome, to: :funcionario, prefix: true
  delegate :nome, to: :empresa, prefix: true

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
