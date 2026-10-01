module Fiscal
  # Orquestra a emissao de uma venda: cria o DocumentoFiscal (rascunho),
  # monta o payload via DocumentoFiscalBuilder, chama o FiscalService (provedor)
  # e PERSISTE o resultado (chave, protocolo, XML, DANFE, status) no documento.
  #
  # Uso:
  #   doc = Fiscal::EmissorFiscal.new(venda, modelo: 65, cod_funcionario: 1).emitir
  #   doc.autorizada?  # => true/false
  #
  # Nao lanca excecao em rejeicao: grava o status/mensagem no documento.
  class EmissorFiscal
    class SemConfig < StandardError; end
    class SemOperacao < StandardError; end

    def initialize(venda, modelo: 65, operacao: nil, cod_funcionario: nil)
      @venda   = venda
      @modelo  = modelo
      @empresa = venda.empresa
      @config  = FiscalConfig.find_by(cod_empresa: @empresa.cod_empresa)
      @operacao = operacao || OperacaoFiscal.find_by(nome: "Venda")
      @cod_funcionario = cod_funcionario
    end

    def emitir
      raise SemConfig,   "Empresa sem configuração fiscal ativa" unless @config&.ativo?
      raise SemOperacao, "Operação fiscal 'Venda' não encontrada" if @operacao.nil?

      documento = criar_documento_rascunho
      doc_payload = DocumentoFiscalBuilder.new(@venda, operacao: @operacao, config: @config, modelo: @modelo).montar
      documento.update!(status: "enviada")

      result = FiscalService.new(@config).emitir(doc_payload)
      documento.aplicar_resultado!(result)
      documento
    rescue => e
      # Falha inesperada (rede, etc.): registra erro no documento se ja existe.
      if defined?(documento) && documento&.persisted?
        documento.update(status: "erro", mensagem_sefaz: e.message.to_s[0, 255])
      end
      Rails.logger.error("[EmissorFiscal] venda #{@venda&.cod_venda}: #{e.class} - #{e.message}")
      raise
    end

    private

    def criar_documento_rascunho
      DocumentoFiscal.create!(
        cod_empresa:        @empresa.cod_empresa,
        cod_venda:          @venda.try(:cod_venda),
        modelo:             @modelo,
        natureza_operacao:  @operacao.natureza_operacao,
        finalidade:         1,
        ambiente:           @config.ambiente,
        status:             "rascunho",
        cod_funcionario:    @cod_funcionario,
        provedor:           @config.provedor
      )
    end
  end
end
