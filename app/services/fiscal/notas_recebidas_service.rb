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

    # REGISTRA (grava só os dados, SEM baixar XML) as notas de entrada do periodo
    # vindas da distribuicao (ObterNotasFiscais). Dedupe por chave: ja existente
    # nao e tocada. Retorna Resultado (novas/atualizadas). O XML so e baixado
    # depois, sob demanda (baixar/importar). Leitura pura na SEFAZ — nao manifesta.
    def registrar_periodo!(dt_inicio:, dt_fim:)
      resp = @adapter.obter_notas(dt_inicio: dt_inicio, dt_fim: dt_fim, tipo_documento: 0)
      erro = resp["Error"].to_s
      notas = resp["Notas"] || resp["notas"] || []

      if erro.present? && notas.empty? && !erro.downcase.include?("existe")
        return Resultado.new(novas: 0, atualizadas: 0, erro: true, mensagem: erro)
      end

      novas = 0
      Array(notas).each do |n|
        chave = (n["Chave"] || n["ChaveNF"] || n["chave"]).to_s.gsub(/\D/, "")
        next if chave.blank?
        next if NotaRecebida.exists?(cod_empresa: @empresa.cod_empresa, chave_acesso: chave)
        novas += 1 if registrar_dados!(chave, n)
      end

      Resultado.new(novas: novas, atualizadas: 0, erro: false,
                    mensagem: notas.empty? ? "Nenhuma nota no período." : "#{novas} nova(s) registrada(s).")
    rescue => e
      Rails.logger.error("[NotasRecebidasService#registrar_periodo] #{e.class} - #{e.message}")
      Resultado.new(novas: 0, atualizadas: 0, erro: true, mensagem: e.message)
    end

    # Grava UMA nota (só dados, SEM XML) a partir do resumo da API. Usado pelo
    # registro automatico do periodo e pelo "Salvar" da consulta por chave.
    # Dedupe por chave (nao duplica). Retorna a NotaRecebida ou nil.
    def registrar_dados!(chave, resumo_api)
      chave = chave.to_s.gsub(/\D/, "")
      return nil if chave.blank?
      existente = NotaRecebida.find_by(cod_empresa: @empresa.cod_empresa, chave_acesso: chave)
      return existente if existente

      cnpj = (resumo_api["CnpjEmissor"] || resumo_api["CnpjEmitente"]).to_s.gsub(/\D/, "").presence
      fornecedor = cnpj ? Pessoa.find_by(cpf_cnpj: cnpj) : nil

      nota = NotaRecebida.new(
        cod_empresa:   @empresa.cod_empresa,
        chave_acesso:  chave,
        origem:        "sefaz",
        status_sefaz:  mapear_status_api(resumo_api["Status"]),
        status_sincronizado_em: Time.current,
        cod_pessoa:    fornecedor&.cod_pessoa,
        numero:        resumo_api["Numero"],
        serie:         resumo_api["Serie"],
        modelo:        resumo_api["ModeloDocumento"],
        valor_total:   resumo_api["Valor"],
        emitente_cnpj: cnpj,
        emitente_nome: resumo_api["NomeEmissor"] || resumo_api["NomeEmitente"],
        data_emissao:  parse_data_api(resumo_api["DtEmissao"] || resumo_api["DataEmissao"])
      )
      # vincula a compra ja existente (se a nota ja tinha sido importada antes)
      vincular_compra_existente(nota, fornecedor)
      nota.save!
      nota
    rescue => e
      Rails.logger.error("[NotasRecebidasService#registrar_dados chave=#{chave}] #{e.class} - #{e.message}")
      nil
    end

    # Importa UMA nota pela chave SOB DEMANDA (clicou em "Importar" na lista):
    # baixa o XML da SEFAZ, cria/garante o XmlFile e grava/atualiza a NotaRecebida.
    # Reaproveita o registro existente (dedupe por chave) para nao duplicar.
    # Retorna a NotaRecebida (com xml_file) ou nil em falha. NAO vira compra aqui
    # — so prepara o XmlFile; a compra e montada na tela seguinte (produtoxmls#new).
    def importar_chave!(chave)
      chave = chave.to_s.gsub(/\D/, "")
      return nil if chave.blank?

      nota = NotaRecebida.find_by(cod_empresa: @empresa.cod_empresa, chave_acesso: chave)
      # Ja importada e com XML -> reaproveita.
      return nota if nota&.xml_file_id.present?

      if nota
        # Registro existe mas sem XML: baixa e anexa agora.
        anexar_xml!(nota, chave)
        nota
      else
        # Novo: cria a partir da chave (baixa XML + cria XmlFile + grava registro).
        criar_a_partir_da_chave(chave, {}) ? NotaRecebida.find_by(cod_empresa: @empresa.cod_empresa, chave_acesso: chave) : nil
      end
    rescue => e
      Rails.logger.error("[NotasRecebidasService#importar_chave] chave=#{chave}: #{e.class} - #{e.message}")
      nil
    end

    private

    # Baixa o XML e anexa a uma NotaRecebida ja existente (sem XML), preenchendo
    # tambem os dados que faltarem (fornecedor/numero/serie...).
    def anexar_xml!(nota, chave)
      arquivo = @adapter.obter_arquivo(chave: chave, file_type: 1, tipo_documento: 0)
      return unless arquivo.sucesso?
      xml = arquivo.conteudo
      r = Fiscal::XmlNotaResumo.new(xml) rescue nil
      fornecedor = (r && r.valido?) ? resolver_fornecedor(r) : nil
      nota.xml_file = criar_xml_file(xml, chave, fornecedor)
      nota.cod_pessoa ||= fornecedor&.cod_pessoa
      nota.save!
    end

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

    # Status da listagem da API (1=autorizada) -> vocabulario do sistema.
    def mapear_status_api(valor)
      case valor.to_i
      when 1 then "autorizada"
      when 2 then "cancelada"
      when 4 then "denegada"
      else "autorizada" # listada pela SEFAZ sem status claro = tratada como autorizada
      end
    end

    # Converte a data da API (ISO/date-time) para Date; nil se invalida.
    def parse_data_api(valor)
      return nil if valor.blank?
      (Time.parse(valor.to_s).to_date rescue (Date.parse(valor.to_s) rescue nil))
    end
  end
end
