# frozen_string_literal: true

# Cria uma ProdutoImagem (biblioteca do produto) a partir de um arquivo enviado.
# Centraliza o processamento de imagem (resize, HEIC->JPEG, nome do arquivo)
# que antes estava duplicado no ProdutoImagensController.
class ProdutoImagemUploadService
  RESIZE = "1920x1080"

  Result = Struct.new(:sucesso, :produto_imagem, :erro, :duplicada, keyword_init: true) do
    def sucesso?
      sucesso
    end

    def duplicada?
      duplicada
    end
  end

  def self.call(produto:, cor:, arquivo:, forcar: false)
    new(produto: produto, cor: cor, arquivo: arquivo, forcar: forcar).call
  end

  # Apenas verifica se a imagem (pelo conteúdo processado) já existe para o produto.
  # Não grava nada. Retorna true/false.
  def self.duplicada?(produto:, arquivo:)
    new(produto: produto, cor: nil, arquivo: arquivo).duplicada?
  end

  def initialize(produto:, cor:, arquivo:, forcar: false)
    @produto = produto
    @cor     = cor
    @arquivo = arquivo
    @forcar  = forcar
  end

  def call
    return Result.new(sucesso: false, erro: "Parâmetros inválidos") unless @produto && @cor && @arquivo

    dados    = processar
    extensao = File.extname(@arquivo.original_filename.to_s).downcase

    # Evita gravar a mesma imagem (mesmo conteúdo) para o mesmo produto,
    # a menos que o colaborador tenha confirmado (forcar).
    if !@forcar && imagem_duplicada?(dados)
      return Result.new(sucesso: false, duplicada: true,
                        erro: "Esta imagem já foi cadastrada para este produto.")
    end

    produto_imagem = ProdutoImagem.new(produto: @produto, cor: @cor)
    produto_imagem.imagem.attach(
      io: StringIO.new(dados),
      filename: nome_arquivo(extensao),
      content_type: "image/jpeg"
    )

    if produto_imagem.save
      Result.new(sucesso: true, produto_imagem: produto_imagem)
    else
      Result.new(sucesso: false, erro: produto_imagem.errors.full_messages.join(", "))
    end
  end

  # Processa a imagem e verifica se já existe igual para o produto (sem gravar).
  def duplicada?
    return false unless @produto && @arquivo

    imagem_duplicada?(processar)
  end

  private

  # Processa a imagem (resize, HEIC->JPEG) e devolve os bytes resultantes.
  def processar
    imagem = MiniMagick::Image.read(@arquivo.tempfile)
    extensao = File.extname(@arquivo.original_filename.to_s).downcase
    imagem.format "jpeg" if heic?(extensao)
    imagem.resize RESIZE
    imagem.to_blob
  end

  # Verifica se já existe uma imagem com o mesmo conteúdo para o mesmo produto.
  # Compara pelo checksum (MD5 em base64) do blob processado, mesmo algoritmo
  # usado pelo ActiveStorage, então independe do nome do arquivo.
  def imagem_duplicada?(dados)
    checksum = OpenSSL::Digest::MD5.new.tap { |d| d.update(dados) }.base64digest

    ProdutoImagem
      .where(cod_produto: @produto.cod_produto)
      .joins(imagem_attachment: :blob)
      .where(active_storage_blobs: { checksum: checksum })
      .exists?
  end

  def heic?(extensao)
    @arquivo.content_type == "image/heic" || extensao == ".heic"
  end

  def nome_arquivo(extensao)
    nome_base = @produto.nome.to_s.split(" ")[0..1].join(" ")
    base      = File.basename(@arquivo.original_filename.to_s, extensao)
    "#{nome_base}_#{base}.jpeg"
  end
end
