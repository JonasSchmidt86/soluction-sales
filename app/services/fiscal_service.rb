# Interface NEUTRA de emissão fiscal (Fatia 2 - Parte A).
#
# O sistema fala SEMPRE com esta classe, nunca direto com o provedor.
# Assim, trocar Focus <-> Brasil NFe é só trocar o adapter (Parte B),
# sem mexer no restante do sistema.
#
# Nesta fase (Parte A) não há provedor concreto: os métodos existem como
# contrato e levantam NotImplementedError até um adapter ser plugado.
#
# Uso futuro (Parte B):
#   service = FiscalService.new(fiscal_config)   # escolhe o adapter pelo config.provedor
#   resultado = service.emitir(documento_fiscal)
#
# Todos os métodos devem retornar um FiscalResult (sucesso?, dados, erros),
# padronizado independente do provedor.
class FiscalService
  class NaoConfigurado < StandardError; end

  attr_reader :config, :adapter

  def initialize(config = nil, adapter: nil)
    @config = config
    @adapter = adapter || build_adapter(config)
  end

  # Escolhe o adapter concreto pelo provedor configurado.
  def build_adapter(config)
    return nil if config.nil?

    case config.provedor.to_s
    when "brasilnfe"
      Fiscal::BrasilNfeAdapter.new(config: config)
    when "focus"
      nil # FocusAdapter — implementar se um dia trocar de provedor
    else
      nil
    end
  end

  # --- Contrato (o que qualquer adapter deve implementar) ---

  # Emite um documento fiscal (NF-e 55 ou NFC-e 65).
  def emitir(documento)
    delegar(:emitir, documento)
  end

  # Consulta a situação de um documento já enviado.
  def consultar(referencia)
    delegar(:consultar, referencia)
  end

  # Cancela um documento autorizado (dentro do prazo da SEFAZ).
  def cancelar(referencia, justificativa)
    delegar(:cancelar, referencia, justificativa)
  end

  # Carta de correção eletrônica.
  def carta_correcao(referencia, texto)
    delegar(:carta_correcao, referencia, texto)
  end

  # Inutiliza uma faixa de numeração não usada.
  def inutilizar(serie:, numero_inicial:, numero_final:, justificativa:)
    delegar(:inutilizar, serie: serie, numero_inicial: numero_inicial,
                         numero_final: numero_final, justificativa: justificativa)
  end

  # Emite uma nota de devolução (espelha a nota de origem).
  def devolver(documento_origem, itens)
    delegar(:devolver, documento_origem, itens)
  end

  # Pré-visualiza o documento (PDF/XML) sem transmitir à SEFAZ. Retorna
  # FiscalPreview. tipo_arquivo: 1 = PDF (default), 0 = XML.
  def pre_visualizar(documento, tipo_arquivo: 1, tarja: true)
    delegar(:pre_visualizar, documento, tipo_arquivo: tipo_arquivo, tarja: tarja)
  end

  private

  def delegar(metodo, *args, **kwargs)
    if adapter.nil?
      raise NaoConfigurado,
            "Nenhum provedor fiscal configurado. Defina o adapter (Focus/Brasil NFe) na Parte B."
    end
    adapter.public_send(metodo, *args, **kwargs)
  end
end
