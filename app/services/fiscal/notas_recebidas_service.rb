module Fiscal
  # Recebimento de notas de ENTRADA (emitidas por fornecedores contra o CNPJ da
  # empresa). Busca na SEFAZ via Brasil NFe (ObterNotasFiscais entradas), baixa
  # o XML de cada chave nova, extrai o resumo e grava/atualiza NotaRecebida.
  # Dedupe por (empresa, chave). Em producao traz notas reais; em homologacao
  # a listagem vem vazia (sem emissoes reais contra o CNPJ).
  #
  # Uso:
  #   Fiscal::NotasRecebidasService.new(empresa).sincronizar!(dt_inicio:, dt_fim:)
  class NotasRecebidasService
    Resultado = Struct.new(:novas, :atualizadas, :erro, :mensagem, keyword_init: true)

    def initialize(empresa)
      @empresa = empresa
      @config  = FiscalConfig.find_by(cod_empresa: empresa.cod_empresa)
      @adapter = Fiscal::BrasilNfeAdapter.new(config: @config)
    end

    # Busca as notas de entrada do periodo e grava as novas como NotaRecebida.
    # Baixa o XML de cada nota nova para extrair o resumo completo (fornecedor,
    # serie, transportadora, natureza...). Retorna Resultado.
    def sincronizar!(dt_inicio:, dt_fim:)
      resp = @adapter.obter_notas(dt_inicio: dt_inicio, dt_fim: dt_fim, tipo_documento: 0)
      erro = resp["Error"].to_s
      notas = resp["Notas"] || resp["notas"] || []

      # "Nao existe notas" nao e erro de verdade (periodo vazio) — comum em homolog.
      if erro.present? && notas.empty? && !erro.downcase.include?("nao existe") && !erro.downcase.include?("não existe")
        return Resultado.new(novas: 0, atualizadas: 0, erro: true, mensagem: erro)
      end

      novas = 0
      atualizadas = 0
      notas.each do |n|
        chave = (n["Chave"] || n["ChaveNF"] || n["chave"]).to_s.gsub(/\D/, "")
        next unless chave.length == 44
        existente = NotaRecebida.find_by(cod_empresa: @empresa.cod_empresa, chave_acesso: chave)
        if existente
          atualizadas += 1 if atualizar_status(existente)
        else
          criar_a_partir_da_chave(chave, n) ? novas += 1 : nil
        end
      end

      Resultado.new(novas: novas, atualizadas: atualizadas, erro: false,
                    mensagem: "#{novas} nova(s), #{atualizadas} atualizada(s).")
    rescue => e
      Rails.logger.error("[NotasRecebidasService#sincronizar] #{e.class} - #{e.message}")
      Resultado.new(novas: 0, atualizadas: 0, erro: true, mensagem: e.message)
    end

    private

    # Baixa o XML da nota (entrada) e cria a NotaRecebida com o resumo extraido.
    def criar_a_partir_da_chave(chave, resumo_api)
      arquivo = @adapter.obter_arquivo(chave: chave, file_type: 1, tipo_documento: 0)
      xml = arquivo.sucesso? ? arquivo.conteudo : nil

      r = xml ? Fiscal::XmlNotaResumo.new(xml) : nil
      fornecedor = (r && r.valido?) ? resolver_fornecedor(r) : nil

      nota = NotaRecebida.new(
        cod_empresa:   @empresa.cod_empresa,
        chave_acesso:  chave,
        origem:        "sefaz",
        status_sefaz:  "autorizada", # listada pela SEFAZ = autorizada (status refina depois)
        status_sincronizado_em: Time.current
      )

      if r && r.valido?
        nota.assign_attributes(
          cod_pessoa:          fornecedor&.cod_pessoa,
          modelo:              r.modelo,
          numero:              r.numero,
          serie:               r.serie,
          data_emissao:        r.data_emissao,
          valor_total:         r.valor_total,
          emitente_cnpj:       r.emitente_cnpj,
          emitente_nome:       r.emitente_nome,
          natureza_operacao:   r.natureza,
          tipo_nf:             r.tipo_nf,
          transportadora_nome: r.transportadora_nome,
          transportadora_cnpj: r.transportadora_cnpj
        )
        nota.xml_file = criar_xml_file(xml, chave, fornecedor) if xml
      else
        # Sem XML (ex. so o resumo da listagem): grava o minimo da API.
        nota.numero      = resumo_api["Numero"]
        nota.serie       = resumo_api["Serie"]
        nota.modelo      = resumo_api["ModeloDocumento"]
        nota.valor_total = resumo_api["Valor"]
      end

      # vincula a compra ja existente (se a nota ja tinha sido importada antes)
      vincular_compra_existente(nota, fornecedor)
      nota.save!
      true
    rescue => e
      Rails.logger.error("[NotasRecebidasService#criar chave=#{chave}] #{e.class} - #{e.message}")
      false
    end

    # Atualiza o status SEFAZ de uma nota ja existente (detecta cancelamento).
    def atualizar_status(nota)
      situacao = consultar_situacao(nota.chave_acesso)
      return false if situacao.nil?
      if nota.status_sefaz != situacao
        nota.update(status_sefaz: situacao, status_sincronizado_em: Time.current)
        true
      else
        nota.update_column(:status_sincronizado_em, Time.current)
        false
      end
    end

    # Consulta a situacao da nota na SEFAZ (autorizada/cancelada/denegada).
    def consultar_situacao(chave)
      consulta = @adapter.consultar(chave) rescue nil
      return nil if consulta.nil? || !consulta.respond_to?(:situacao)
      map = { autorizada: "autorizada", cancelada: "cancelada", denegada: "denegada" }
      map[consulta.situacao] || nil
    end

    # Resolve o fornecedor pelo CNPJ do emitente; cria se nao existir (mesma
    # logica do upload manual de XML).
    def resolver_fornecedor(r)
      cnpj = r.emitente_cnpj
      return nil if cnpj.blank?
      f = Pessoa.find_by(cpf_cnpj: cnpj)
      return f if f

      end_emit = r.emitente_endereco
      f = Pessoa.new(
        tipo:     "J",
        cpf_cnpj: cnpj,
        rg_ie:    r.emitente_ie,
        nome:     r.emitente_nome,
        apelido:  r.emitente_fant.presence || r.emitente_nome,
        endereco: end_emit[:logradouro],
        numero:   end_emit[:numero],
        bairro:   end_emit[:bairro],
        cep:      end_emit[:cep],
        telefone: end_emit[:fone]
      )
      f.cod_cidade = (ViacepService.get_id_cidade(end_emit[:cep]) rescue nil) || 1
      f.save
      f
    rescue => e
      Rails.logger.error("[NotasRecebidasService#resolver_fornecedor] #{e.class} - #{e.message}")
      nil
    end

    # Cria o XmlFile reaproveitando a infra atual (blob em storage/XML com key
    # <empresa>/<ano>/NFe<chave>), para o fluxo de importacao->compra funcionar.
    def criar_xml_file(xml, chave, fornecedor)
      nome_arquivo = "NFe#{chave}"
      existente = XmlFile.joins(file_attachment: :blob)
                         .find_by(active_storage_blobs: { filename: nome_arquivo })
      return existente if existente

      xf = XmlFile.new(empresa: @empresa, pessoa: fornecedor, name: fornecedor&.apelido)
      io = StringIO.new(xml)
      io.define_singleton_method(:content_type) { "application/xml" }
      io.define_singleton_method(:original_filename) { nome_arquivo }
      xf.attach_file_with_custom_service(io, nome_arquivo, @empresa)
      xf.save!
      xf
    rescue => e
      Rails.logger.error("[NotasRecebidasService#criar_xml_file] #{e.class} - #{e.message}")
      nil
    end

    def vincular_compra_existente(nota, fornecedor)
      return if fornecedor.nil? || nota.numero.blank?
      compra = Compra.find_by(numeronf: nota.numero, cod_pessoa: fornecedor.cod_pessoa)
      nota.cod_compra = compra&.cod_compra if compra
    end
  end
end
