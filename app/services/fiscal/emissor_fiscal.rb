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
    class JaAutorizada < StandardError; end
    class DadosFiscaisIncompletos < StandardError; end

    # Status de um documento que pode ser REAPROVEITADO numa reemissao.
    # Rejeitada/erro = tentativa que falhou (corrige e reenvia o MESMO doc).
    # Rascunho/enviada = ficou pela metade (ex: queda de rede antes do retorno).
    STATUS_REAPROVEITAVEIS = %w[rascunho enviada rejeitada erro].freeze

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

      documento = documento_para_emissao
      builder = DocumentoFiscalBuilder.new(@venda, operacao: @operacao, config: @config, modelo: @modelo)
      doc_payload = builder.montar

      # Trava: NAO envia para a SEFAZ se faltar dado fiscal essencial. Em
      # homologacao a SEFAZ costuma autorizar notas incompletas (sem CFOP/CST),
      # o que mascara o erro; em producao seria rejeitada. Falhar aqui evita
      # emitir nota invalida e deixa claro o que corrigir.
      pendencias = validar_dados_fiscais(doc_payload)
      if pendencias.any?
        documento.update(status: "erro", mensagem_sefaz: "Dados fiscais incompletos: #{pendencias.join('; ')}"[0, 255])
        raise DadosFiscaisIncompletos, "Não é possível emitir. #{pendencias.join('; ')}"
      end

      documento.update!(status: "enviada", mensagem_sefaz: nil)

      result = FiscalService.new(@config).emitir(doc_payload)
      documento.aplicar_resultado!(result)

      # Autorizada: baixa o ESTOQUE FISCAL (qtdfiscal) dos itens cuja regra
      # controla estoque (antes isso era da trigger de venda; agora é no Rails).
      baixar_estoque_fiscal(documento, builder.itens_estoque_fiscal) if documento.autorizada?

      documento
    rescue JaAutorizada, DadosFiscaisIncompletos
      raise
    rescue => e
      # Falha inesperada (rede, etc.): registra erro no documento se ja existe.
      if defined?(documento) && documento&.persisted?
        documento.update(status: "erro", mensagem_sefaz: e.message.to_s[0, 255])
      end
      Rails.logger.error("[EmissorFiscal] venda #{@venda&.cod_venda}: #{e.class} - #{e.message}")
      raise
    end

    private

    # Baixa o estoque fiscal (qtdfiscal) apos a NF ser autorizada. Falha aqui
    # NAO desfaz a emissao (a NF ja esta autorizada na SEFAZ); loga o erro.
    def baixar_estoque_fiscal(documento, itens)
      Fiscal::EstoqueFiscalService.new(
        cod_empresa:     @empresa.cod_empresa,
        itens:           itens,
        cod_referencia:  documento.cod_documento_fiscal,
        cod_funcionario: @cod_funcionario,
        observacao:      "Emissao NF modelo #{@modelo} (doc #{documento.cod_documento_fiscal})"
      ).baixar!
    rescue => e
      Rails.logger.error("[EmissorFiscal] baixa estoque fiscal doc #{documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    end

    # Verifica o documento neutro montado. Retorna uma lista de pendencias
    # (vazia = ok). Checa, por item: NCM, CFOP e CSOSN (CST do ICMS). Sem esses
    # a nota e invalida (producao rejeita; homologacao engana autorizando).
    def validar_dados_fiscais(payload)
      pendencias = []
      produtos = Array(payload[:produtos])

      pendencias << "Venda sem itens" if produtos.empty?

      produtos.each do |p|
        nome = p["NmProduto"].presence || "produto #{p["CodProdutoServico"]}"
        pendencias << "#{nome}: sem NCM" if p["NCM"].blank? || p["NCM"].to_s == "00000000"
        pendencias << "#{nome}: sem CFOP (verifique perfil/regra fiscal)" if p["CFOP"].blank?
        csosn = p.dig("Imposto", "ICMS", "CodSituacaoTributaria")
        pendencias << "#{nome}: sem CSOSN/CST de ICMS (verifique a regra fiscal)" if csosn.blank?
      end

      pendencias
    end

    # Reaproveita o documento da venda quando existe e ainda nao foi autorizado.
    # Se ja esta autorizado, nao deixa reemitir (precisa cancelar). Se nao existe,
    # cria um rascunho novo.
    def documento_para_emissao
      existente = DocumentoFiscal
                  .where(cod_venda: @venda.cod_venda, modelo: @modelo)
                  .order(cod_documento_fiscal: :desc)
                  .first

      if existente&.autorizada?
        raise JaAutorizada, "Já existe NF autorizada para esta venda (chave #{existente.chave_acesso}). Cancele antes de reemitir."
      end

      if existente && STATUS_REAPROVEITAVEIS.include?(existente.status)
        existente.update!(
          status:            "rascunho",
          natureza_operacao: @operacao.natureza_operacao,
          ambiente:          @config.ambiente,
          provedor:          @config.provedor,
          cod_funcionario:   @cod_funcionario || existente.cod_funcionario,
          mensagem_sefaz:    nil,
          cod_status_sefaz:  nil
        )
        return existente
      end

      criar_documento_rascunho
    end

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
