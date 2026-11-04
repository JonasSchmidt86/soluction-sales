module Fiscal
  # Entrega os arquivos de uma NF-e AUTORIZADA (DANFE em PDF e XML) para envio ao
  # cliente (e-mail anexo / link publico). Usa o que ja esta salvo no documento;
  # se faltar, busca no provedor pela chave (ObterArquivoNotaFiscal) — mesmo
  # comportamento do DocumentosFiscaisController, para o arquivo estar sempre
  # disponivel.
  #
  # Devolve String binaria (conteudo) ou nil quando indisponivel.
  class ArquivosNota
    def initialize(documento)
      @documento = documento
    end

    # PDF do DANFE. So devolve se for PDF de verdade (a NFC-e vem em HTML e nao
    # entra neste fluxo de envio).
    def danfe_pdf
      conteudo = decodificar(@documento.danfe_base64) || buscar(file_type: 2)
      conteudo if conteudo.to_s.start_with?("%PDF")
    end

    def xml
      decodificar(@documento.xml_base64) || buscar(file_type: 1)
    end

    private

    def decodificar(base64)
      base64.present? ? Base64.decode64(base64) : nil
    end

    def buscar(file_type:)
      return nil if @documento.chave_acesso.blank?

      config = FiscalConfig.find_by(cod_empresa: @documento.cod_empresa)
      return nil if config.nil? || !config.ativo?

      arquivo = FiscalService.new(config).obter_arquivo(
        chave: @documento.chave_acesso, file_type: file_type, tipo_documento: 1
      )
      arquivo&.sucesso? ? arquivo.conteudo : nil
    rescue => e
      Rails.logger.error("[Fiscal::ArquivosNota] doc #{@documento.cod_documento_fiscal} file_type=#{file_type}: #{e.class} - #{e.message}")
      nil
    end
  end
end
