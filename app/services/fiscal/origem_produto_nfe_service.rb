require "time"
require "date"

module Fiscal
  class OrigemProdutoNfeService
    ORIGENS_VALIDAS = (0..8).map(&:to_s).freeze
    CAMPOS_FISCAIS = %i[origem ncm cest gtin ucom].freeze

    def initialize(xml_files: nil, mappings_for: nil, find_product: nil, persistor: nil, transaction_runner: nil)
      @xml_files = xml_files || XmlFile.includes(:empresa, :pessoa, :compra, file_attachment: :blob).find_each
      @mappings_for = mappings_for || ->(cprod, supplier_id) {
        Produtoxml.where(codproemissor: cprod, cod_pessoa: supplier_id).to_a
      }
      @find_product = find_product || ->(cod_produto) { Produto.find_by(cod_produto: cod_produto) }
      @persistor = persistor || method(:persistir_origem!)
      @transaction_runner = transaction_runner || ->(&block) { ActiveRecord::Base.transaction(&block) }
      @mapping_cache = {}
      @product_cache = {}
    end

    def executar(apply: false)
      relatorio = {
        modo: apply ? "APPLY" : "DRY-RUN",
        xmls_total: 0,
        xmls_analisados: 0,
        xmls_validos: 0,
        xmls_invalidos: 0,
        xmls_ignorados: 0,
        falhas_xml: [],
        produtos: {},
        nao_encontrados: {},
        vinculos_ambiguos: {},
        falhas_gravacao: []
      }

      @xml_files.each do |xml_file|
        relatorio[:xmls_total] += 1
        unless xml_file.compra_id.present?
          relatorio[:xmls_ignorados] += 1
          next
        end
        if xml_file.compra&.cancelada?
          relatorio[:xmls_ignorados] += 1
          next
        end

        relatorio[:xmls_analisados] += 1
        doc, erro = carregar_xml(xml_file)
        unless doc
          relatorio[:xmls_invalidos] += 1
          relatorio[:falhas_xml] ||= []
          relatorio[:falhas_xml] << { arquivo: identificador_xml(xml_file), motivo: erro }
          next
        end

        compatibilidade = validar_documento(doc, xml_file)
        if compatibilidade
          relatorio[:xmls_invalidos] += 1
          relatorio[:falhas_xml] ||= []
          relatorio[:falhas_xml] << { arquivo: identificador_xml(xml_file), motivo: compatibilidade }
          next
        end

        relatorio[:xmls_validos] += 1
        analisar_itens(doc, xml_file, relatorio)
      end

      classificar_produtos!(relatorio)
      aplicar_alteracoes!(relatorio) if apply
      relatorio
    end

    private

    def carregar_xml(xml_file)
      return [nil, "arquivo XML ausente"] unless xml_file.file.attached?

      conteudo = xml_file.file.download
      doc = Nokogiri::XML(conteudo) { |config| config.strict.nonet }
      [doc, nil]
    rescue Nokogiri::XML::SyntaxError => e
      [nil, "XML malformado: #{e.message.lines.first.to_s.strip}"]
    rescue StandardError => e
      [nil, "falha ao ler XML: #{e.message}"]
    end

    def validar_documento(doc, xml_file)
      inf_nfes = doc.xpath('//*[local-name()="infNFe"]')
      return "infNFe ausente ou duplicada" unless inf_nfes.one?

      tipo_nf = texto(doc, '//*[local-name()="ide"]/*[local-name()="tpNF"]')
      return "tpNF ausente" if tipo_nf.blank?
      return "tpNF inválido: #{tipo_nf}" unless %w[0 1].include?(tipo_nf)

      cnpj_destino = digitos(texto(doc, '//*[local-name()="dest"]/*[local-name()="CNPJ"]') ||
                             texto(doc, '//*[local-name()="dest"]/*[local-name()="CPF"]'))
      cnpj_empresa = digitos(xml_file.empresa&.cpf_cnpj)
      return "empresa de destino não identificada" if cnpj_empresa.blank?
      return "XML destinado a outra empresa" if cnpj_destino.blank? || cnpj_destino != cnpj_empresa

      cnpj_emitente = digitos(texto(doc, '//*[local-name()="emit"]/*[local-name()="CNPJ"]') ||
                              texto(doc, '//*[local-name()="emit"]/*[local-name()="CPF"]'))
      cnpj_fornecedor = digitos(xml_file.pessoa&.cpf_cnpj)
      if cnpj_fornecedor.present? && cnpj_emitente != cnpj_fornecedor
        return "emitente diferente do fornecedor vinculado ao XML"
      end

      nil
    end

    def analisar_itens(doc, xml_file, relatorio)
      inf_nfe = doc.at_xpath('//*[local-name()="infNFe"]')
      chave = inf_nfe_chave(inf_nfe)
      numero_nf = texto(doc, '//*[local-name()="ide"]/*[local-name()="nNF"]')
      data_emissao = data_emissao(doc)
      fornecedor_nome = texto(doc, '//*[local-name()="emit"]/*[local-name()="xNome"]') ||
                        xml_file.pessoa&.apelido || xml_file.pessoa&.nome || "(não identificado)"
      fornecedor_id = xml_file.pessoa&.id

      inf_nfe.xpath('.//*[local-name()="det"]').each do |det|
        produto_xml = det.at_xpath('./*[local-name()="prod"]')
        cprod = texto(produto_xml, './*[local-name()="cProd"]')
        nome_xml = texto(produto_xml, './*[local-name()="xProd"]')
        gtin_raw = gtin_xml(produto_xml)
        ncm = texto(produto_xml, './*[local-name()="NCM"]')
        cest = texto(produto_xml, './*[local-name()="CEST"]')
        ucom = texto(produto_xml, './*[local-name()="uCom"]')
        cfop = texto(produto_xml, './*[local-name()="CFOP"]')
        tags_origem = det.xpath('./*[local-name()="imposto"]/*[local-name()="ICMS"]/*/*[local-name()="orig"]')
        origem_raw = tags_origem.one? ? tags_origem.first.text.to_s.strip.presence :
          (tags_origem.any? ? tags_origem.map { |tag| tag.text.to_s.strip }.join(",") : nil)
        valores_xml = {
          origem: origem_raw,
          ncm: ncm,
          cest: cest,
          gtin: gtin_raw,
          ucom: ucom
        }
        valores_validos = {}
        valores_xml.each do |campo, valor|
          valores_validos[campo] = validar_campo(campo, valor)
        end
        validacoes = valores_xml.each_with_object({}) do |(campo, valor), resultado|
          resultado[campo] = if valor.blank?
            :ausente
          elsif valores_validos[campo].present?
            :valido
          else
            :invalido
          end
        end
        ocorrencia = {
          cprod: cprod.presence || "(vazio)",
          nome_xml: nome_xml.presence || "(não informado)",
          gtin: gtin_raw.presence || "(não informado)",
          ncm: ncm.presence || "(não informado)",
          cest: cest.presence || "(não informado)",
          origem: origem_raw,
          ucom: ucom.presence || "(não informado)",
          cfop: cfop.presence || "(não informado)",
          valores_xml: valores_xml,
          valores_validos: valores_validos,
          validacoes: validacoes,
          fornecedor: fornecedor_nome,
          fornecedor_id: fornecedor_id,
          empresa_id: xml_file.empresa&.id,
          chave_nf: chave,
          numero_nf: numero_nf,
          data_emissao: data_emissao,
          nitem: det["nItem"].to_s.presence || "(não informado)"
        }

        candidatos = if cprod.present? && fornecedor_id.present?
          mapeamentos(cprod, fornecedor_id)
        else
          []
        end

        if candidatos.empty?
          motivo = if cprod.blank?
            "cProd ausente no item XML"
          elsif fornecedor_id.blank?
            "fornecedor não relacionado ao XmlFile"
          else
            "nenhum Produtoxml encontrado para fornecedor_id=#{fornecedor_id} e cProd=#{cprod}"
          end
          registrar_nao_encontrado(relatorio, ocorrencia, motivo: motivo)
          next
        end

        resultado_vinculo = desambiguar(candidatos, det, ocorrencia)
        candidatos = resultado_vinculo[:candidatos]
        codigos_produto = candidatos.map(&:cod_produto).compact.uniq
        if codigos_produto.length != 1
          if codigos_produto.empty?
            registrar_nao_encontrado(relatorio, ocorrencia, motivo: resultado_vinculo[:motivo])
          else
            registrar_ambiguo(relatorio, ocorrencia, codigos_produto, resultado_vinculo[:motivo])
          end
          next
        end

        produto = produto_por_codigo(codigos_produto.first)
        unless produto
          registrar_nao_encontrado(
            relatorio, ocorrencia,
            motivo: "mapeamento aponta para cod_produto=#{codigos_produto.first}, mas o produto não existe"
          )
          next
        end

        ocorrencia[:origem_valida] = ORIGENS_VALIDAS.include?(ocorrencia[:origem])
        registrar_ocorrencia(relatorio, produto, ocorrencia)
      end
    end

    def desambiguar(candidatos, det, ocorrencia)
      return { candidatos: candidatos, motivo: nil } if candidatos.map(&:cod_produto).compact.uniq.length <= 1

      dados = [
        ["infAdProd", texto(det, './*[local-name()="infAdProd"]'), :infadicionais],
        ["GTIN", ocorrencia.dig(:valores_validos, :gtin), :gtin],
        ["NCM", ocorrencia.dig(:valores_validos, :ncm), :ncm]
      ]
      criterios_aplicados = []

      dados.each do |nome_campo, valor_xml, campo|
        next if valor_xml.blank? || valor_xml == "(não informado)"
        candidatos_com_valor = candidatos.select { |candidato| candidato.public_send(campo).present? }
        next if candidatos_com_valor.empty?

        criterios_aplicados << nome_campo
        correspondentes = candidatos_com_valor.select do |candidato|
          normalizar(candidato.public_send(campo)) == normalizar(valor_xml)
        end
        if correspondentes.empty?
          return {
            candidatos: [],
            motivo: "o valor de #{nome_campo} no XML não corresponde a nenhum dos mapeamentos encontrados"
          }
        end
        candidatos = correspondentes
        if candidatos.map(&:cod_produto).compact.uniq.length <= 1
          return { candidatos: candidatos, motivo: nil }
        end
      end

      motivo = if criterios_aplicados.empty?
        "mais de um produto está mapeado para fornecedor+cProd e não há infAdProd, GTIN ou NCM comum para desempatar"
      else
        "após comparar #{criterios_aplicados.join(", ")}, restaram #{candidatos.map(&:cod_produto).compact.uniq.length} cod_produto candidatos"
      end
      { candidatos: candidatos, motivo: motivo }
    end

    def normalizar(valor)
      GenericService.remover_acentos(valor.to_s.gsub(/[.,]/, "").strip.upcase)
    end

    def mapeamentos(cprod, supplier_id)
      @mapping_cache[[supplier_id, cprod]] ||= @mappings_for.call(cprod, supplier_id).to_a
    end

    def produto_por_codigo(cod_produto)
      @product_cache[cod_produto] ||= @find_product.call(cod_produto)
    end

    def registrar_ocorrencia(relatorio, produto, ocorrencia)
      cod_produto = produto.cod_produto
      dados = relatorio[:produtos][cod_produto] ||= { produto: produto, ocorrencias: [], vinculos_ambiguos: [] }
      dados[:ocorrencias] << ocorrencia
    end

    def registrar_nao_encontrado(relatorio, ocorrencia, motivo: nil)
      chave = [ocorrencia[:fornecedor_id], ocorrencia[:cprod]]
      item = relatorio[:nao_encontrados][chave] ||= { ocorrencia: ocorrencia, ocorrencias: [], motivo: motivo }
      ocorrencia[:motivo_nao_encontrado] = motivo if motivo.present?
      item[:ocorrencias] << ocorrencia
    end

    def registrar_ambiguo(relatorio, ocorrencia, codigos_produto, motivo)
      chave = [ocorrencia[:fornecedor_id], ocorrencia[:cprod]]
      item = relatorio[:vinculos_ambiguos][chave] ||= {
        ocorrencia: ocorrencia, codigos_produto: [], motivo: motivo, ocorrencias: []
      }
      detalhe = ocorrencia.merge(codigos_produto_candidatos: codigos_produto, motivo_vinculo_ambiguo: motivo)
      item[:codigos_produto] |= codigos_produto
      item[:ocorrencias] << detalhe
      codigos_produto.each do |codigo|
        produto = produto_por_codigo(codigo)
        next unless produto
        dados = relatorio[:produtos][codigo] ||= { produto: produto, ocorrencias: [], vinculos_ambiguos: [] }
        dados[:vinculos_ambiguos] << detalhe
      end
    end

    def classificar_produtos!(relatorio)
      relatorio[:produtos].each_value { |dados| classificar_produto!(dados) }
    end

    def aplicar_alteracoes!(relatorio)
      resultados = {}
      @transaction_runner.call do
        relatorio[:produtos].each do |cod_produto, dados|
          next unless dados[:elegivel]

          referencia = dados[:referencia]
          contexto = {
            empresa_id: referencia[:empresa_id],
            pessoa_id: referencia[:fornecedor_id],
            numero_nf: referencia[:numero_nf]
          }
          valores = dados[:campos].filter_map do |campo, detalhe|
            [campo, detalhe[:sugerido]] if detalhe[:acao] == :atualizar
          end.to_h
          resultados[cod_produto] = @persistor.call(dados[:produto], valores, contexto)
        end
      end

      resultados.each do |cod_produto, resultado|
        aplicar_resultado!(relatorio[:produtos][cod_produto], resultado)
      end
    rescue StandardError => e
      relatorio[:erro_transacao] = e.message
      relatorio[:produtos].each_value do |dados|
        next unless dados[:elegivel]
        dados[:status] = :rollback
        dados[:acao] = :rollback
        dados[:campos].each_value { |campo| campo[:acao] = :rollback if campo[:acao] == :atualizar }
      end
    end

    def classificar_produto!(dados)
      ocorrencias = ordenar_ocorrencias(dados[:ocorrencias])
      dados[:ocorrencias] = ocorrencias
      dados[:referencia] = ocorrencias.first
      dados[:campos] = {}
      dados[:conflitos_historicos] = {}

      CAMPOS_FISCAIS.each do |campo|
        fonte = dados[:referencia]
        sugerido = fonte&.dig(:valores_validos, campo)
        atual = dados[:produto].public_send(campo).to_s.strip.presence
        raw = fonte&.dig(:valores_xml, campo)
        data_mais_recente = ocorrencias.filter_map { |item| item[:data_emissao] }.max
        valores_data_mais_recente = if data_mais_recente
          ocorrencias.select { |item| item[:data_emissao] == data_mais_recente }
                     .filter_map { |item| item.dig(:valores_validos, campo) }.uniq
        else
          []
        end
        conflito_nf_mais_recente = campo == :gtin && valores_data_mais_recente.size > 1
        acao = if sugerido.blank?
          raw.present? ? :fonte_invalida : :sem_fonte
        elsif campo == :gtin && conflito_nf_mais_recente && atual.blank?
          :conflito_nf_mais_recente
        elsif atual.blank?
          :atualizar
        elsif valores_iguais?(campo, atual, sugerido)
          :ja_correto
        else
          :divergencia_cadastro
        end

        dados[:campos][campo] = {
          atual: atual,
          sugerido: sugerido,
          valor_xml: raw,
          validacao: fonte&.dig(:validacoes, campo) || :sem_fonte,
          conflito_nf_mais_recente: conflito_nf_mais_recente,
          acao: acao,
          fonte: fonte
        }

        ocorrencias_historicas = ocorrencias.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |item, fontes|
          valor = item.dig(:valores_validos, campo)
          fontes[valor] << item if valor.present?
        end
        historico = ocorrencias_historicas.transform_values(&:size)
        alteracoes_antigas = ocorrencias.select do |item|
          valor = item.dig(:valores_validos, campo)
          next false if valor.blank? || valores_iguais?(campo, valor, sugerido)

          if data_mais_recente && item[:data_emissao]
            item[:data_emissao] < data_mais_recente
          else
            !item.equal?(fonte)
          end
        end
        divergencia_historica = historico.size > 1 || (sugerido.blank? && historico.any?)
        dados[:conflitos_historicos][campo] = {
          valores: historico,
          ocorrencias: ocorrencias_historicas,
          alteracoes_antigas: alteracoes_antigas,
          quantidade_alteracoes_antigas: alteracoes_antigas.size,
          uma_alteracao_antiga: alteracoes_antigas.size == 1,
          mais_de_uma_alteracao_antiga: alteracoes_antigas.size > 1,
          valores_data_mais_recente: valores_data_mais_recente,
          conflito_valores_data_mais_recente: valores_data_mais_recente.size > 1,
          referencia: sugerido,
          fonte: fonte
        } if divergencia_historica
      end

      dados[:cfop_atual] = dados[:produto].cfop
      dados[:cfop_xml] = dados[:referencia]&.[](:cfop)
      dados[:elegivel] = dados[:vinculos_ambiguos].empty? && dados[:campos].any? { |_campo, info| info[:acao] == :atualizar }
      acoes = dados[:campos].values.map { |info| info[:acao] }
      dados[:status] = if dados[:vinculos_ambiguos].any?
        :vinculo_ambiguo
      elsif dados[:elegivel]
        :atualizar
      elsif acoes.include?(:divergencia_cadastro)
        :divergencia_cadastro
      elsif acoes.include?(:conflito_nf_mais_recente)
        :conflito_gtin_nf_mais_recente
      elsif dados[:conflitos_historicos].any?
        :conflito_historico
      elsif acoes.include?(:ja_correto)
        :ja_correto
      else
        :sem_fonte_valida
      end
      dados[:acao] = dados[:status]
    end

    def ordenar_ocorrencias(ocorrencias)
      ocorrencias.sort_by do |item|
        data = item[:data_emissao]
        [data ? -data.to_f : Float::INFINITY, item[:chave_nf].to_s]
      end
    end

    def aplicar_resultado!(dados, resultado)
      resultado[:atualizados].each do |campo, valor|
        dados[:campos][campo].merge!(atual: valor, acao: :atualizado)
      end
      resultado[:ja_corretos].each do |campo, valor|
        dados[:campos][campo].merge!(atual: valor, acao: :ja_correto)
      end
      resultado[:divergencias].each do |campo, valor|
        dados[:campos][campo].merge!(atual: valor, acao: :divergencia_cadastro)
      end
      dados[:status] = if resultado[:atualizados].any?
        :atualizado
      elsif resultado[:divergencias].any?
        :divergencia_cadastro
      elsif resultado[:ja_corretos].any?
        :ja_correto
      end
      dados[:acao] = dados[:status]
    end

    def validar_campo(campo, valor)
      texto = valor.to_s.strip
      return nil if texto.blank?

      case campo
      when :origem
        texto if ORIGENS_VALIDAS.include?(texto)
      when :ncm
        texto if texto.match?(/\A\d{8}\z/) && texto != "00000000"
      when :cest
        texto if texto.match?(/\A\d{7}\z/) && texto != "0000000"
      when :gtin
        ean_valido(texto)
      when :ucom
        texto if texto.length <= 8 && texto.match?(/\A[\p{Alnum}][\p{Alnum} .\/_-]*\z/)
      end
    end

    def valores_iguais?(campo, atual, sugerido)
      left = atual.to_s.strip
      right = sugerido.to_s.strip
      campo == :ucom ? left.casecmp?(right) : left == right
    end

    def data_emissao(doc)
      raw = texto(doc, '//*[local-name()="ide"]/*[local-name()="dhEmi"]') ||
            texto(doc, '//*[local-name()="ide"]/*[local-name()="dEmi"]')
      return nil if raw.blank?
      Time.iso8601(raw)
    rescue ArgumentError
      begin
        Date.iso8601(raw).to_time
      rescue ArgumentError
        nil
      end
    end

    def ean_valido(valor)
      digitos = valor.to_s.strip
      return nil unless digitos.match?(/\A(?:\d{8}|\d{12}|\d{13}|\d{14})\z/)

      esperado = digitos[0...-1].chars.reverse.each_with_index.sum do |numero, indice|
        numero.to_i * (indice.even? ? 3 : 1)
      end
      digitos[-1].to_i == (10 - (esperado % 10)) % 10 ? digitos : nil
    end

    def persistir_origem!(produto, valores, contexto)
      resultado = { atualizados: {}, ja_corretos: {}, divergencias: {} }
      produto.with_lock do
        alteracoes = {}
        valores.each do |campo, sugerido|
          atual = produto.public_send(campo).to_s.strip.presence
          if atual.blank?
            ProdutoFiscalLog.create!(
              cod_produto: produto.cod_produto,
              cod_empresa: contexto[:empresa_id],
              cod_pessoa: contexto[:pessoa_id],
              numeronf: contexto[:numero_nf].to_s.presence,
              campo: campo.to_s,
              valor_antigo: atual,
              valor_novo: sugerido,
              created_at: Time.current
            )
            alteracoes[campo] = sugerido
            resultado[:atualizados][campo] = sugerido
          elsif valores_iguais?(campo, atual, sugerido)
            resultado[:ja_corretos][campo] = atual
          else
            resultado[:divergencias][campo] = atual
          end
        end

        produto.update_columns(alteracoes) if alteracoes.any?
      end
      resultado
    end

    def gtin_xml(produto_xml)
      valores = [
        texto(produto_xml, './*[local-name()="cEAN"]'),
        texto(produto_xml, './*[local-name()="cEANTrib"]')
      ].compact
      valores.find { |valor| ean_valido(valor).present? } ||
        valores.find { |valor| valor.present? && !valor.upcase.include?("SEM GTIN") }
    end

    def texto(node, xpath)
      node&.at_xpath(xpath)&.text&.strip.presence
    end

    def digitos(valor)
      valor.to_s.gsub(/\D/, "")
    end

    def inf_nfe_chave(inf_nfe)
      id = inf_nfe&.[]("Id").to_s
      digitos(id).presence || "(não informada)"
    end

    def identificador_xml(xml_file)
      xml_file.file&.filename&.to_s || xml_file.id
    end
  end
end