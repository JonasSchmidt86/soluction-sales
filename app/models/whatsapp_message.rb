class WhatsappMessage < ApplicationRecord
  belongs_to :empresa, foreign_key: 'empresa_id', primary_key: 'cod_empresa'

  validates :titulo, presence: true
  validates :mensagem, presence: true

  scope :ativas, -> { where(ativo: true).order(:ordem, :id) }
  scope :da_empresa, ->(cod_empresa) { where(empresa_id: cod_empresa) }
  scope :da_categoria, ->(categoria) { where(categoria: categoria) }

  # Placeholders suportados na mensagem, no mesmo estilo do custom_report ({{chave}}).
  # A chave (esquerda) é o texto digitado no template; o valor (direita) descreve o dado.
  PLACEHOLDERS = {
    'nome'          => 'Primeiro nome do cliente',
    'nome_completo' => 'Nome completo do cliente',
    'empresa'       => 'Nome da loja/empresa'
  }.freeze

  # Renderiza a mensagem substituindo os placeholders {{...}} pelos dados informados.
  #
  # @param nome_cliente [String] nome completo do cliente
  # @param nome_empresa [String] nome da empresa/loja
  # @return [String] mensagem final pronta para enviar
  def render(nome_cliente: nil, nome_empresa: nil)
    nome_completo = capitalizar_nome(nome_cliente)
    primeiro_nome = nome_completo.split(/\s+/).first.to_s

    valores = {
      'nome'          => primeiro_nome,
      'nome_completo' => nome_completo,
      'empresa'       => nome_empresa.to_s
    }

    texto = mensagem.to_s
    valores.each do |chave, valor|
      texto = texto.gsub("{{#{chave}}}", valor)
    end
    texto
  end

  # Preposições/conectores que permanecem em minúsculo no meio do nome.
  MINUSCULAS_NO_NOME = %w[de da do das dos e].freeze

  # Capitaliza cada palavra do nome, mantendo preposições em minúsculo.
  # Ex.: "MARIA DA SILVA" => "Maria da Silva". A primeira palavra sempre
  # é capitalizada, mesmo que seja uma preposição.
  def capitalizar_nome(nome)
    palavras = nome.to_s.strip.downcase.split(/\s+/)
    palavras.each_with_index.map do |palavra, i|
      if i.positive? && MINUSCULAS_NO_NOME.include?(palavra)
        palavra
      else
        palavra.mb_chars.capitalize.to_s
      end
    end.join(' ')
  end
end
