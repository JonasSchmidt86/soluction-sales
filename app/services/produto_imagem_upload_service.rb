# frozen_string_literal: true

# Cria uma ProdutoImagem (biblioteca do produto) a partir de um arquivo enviado.
# Centraliza o processamento de imagem (resize, HEIC->JPEG, nome do arquivo)
# que antes estava duplicado no ProdutoImagensController.
class ProdutoImagemUploadService
  RESIZE = "1920x1080"

  Result = Struct.new(:sucesso, :produto_imagem, :erro, keyword_init: true) do
    def sucesso?
      sucesso
    end
  end

  def self.call(produto:, cor:, arquivo:)
    new(produto: produto, cor: cor, arquivo: arquivo).call
  end

  def initialize(produto:, cor:, arquivo:)
    @produto = produto
    @cor     = cor
    @arquivo = arquivo
  end

  def call
    return Result.new(sucesso: false, erro: "Parâmetros inválidos") unless @produto && @cor && @arquivo

    imagem = MiniMagick::Image.read(@arquivo.tempfile)

    extensao = File.extname(@arquivo.original_filename.to_s).downcase
    imagem.format "jpeg" if heic?(extensao)
    imagem.resize RESIZE

    produto_imagem = ProdutoImagem.new(produto: @produto, cor: @cor)
    produto_imagem.imagem.attach(
      io: StringIO.new(imagem.to_blob),
      filename: nome_arquivo(extensao),
      content_type: "image/jpeg"
    )

    if produto_imagem.save
      Result.new(sucesso: true, produto_imagem: produto_imagem)
    else
      Result.new(sucesso: false, erro: produto_imagem.errors.full_messages.join(", "))
    end
  end

  private

  def heic?(extensao)
    @arquivo.content_type == "image/heic" || extensao == ".heic"
  end

  def nome_arquivo(extensao)
    nome_base = @produto.nome.to_s.split(" ")[0..1].join(" ")
    base      = File.basename(@arquivo.original_filename.to_s, extensao)
    "#{nome_base}_#{base}.jpeg"
  end
end
