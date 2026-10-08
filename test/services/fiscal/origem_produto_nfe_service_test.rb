require "bundler/setup"
require "minitest/autorun"
require "active_support/core_ext/object/blank"
require "nokogiri"
require_relative "../../../app/services/generic_service"
require_relative "../../../app/services/fiscal/origem_produto_nfe_service"

class OrigemProdutoNfeServiceTest < Minitest::Test
  Company = Struct.new(:id, :cpf_cnpj)
  Supplier = Struct.new(:id, :cpf_cnpj, :apelido, :nome)
  Product = Struct.new(:cod_produto, :nome, :origem, :ncm, :cest, :gtin, :ucom, :cfop)
  Mapping = Struct.new(:cod_produto, :infadicionais, :gtin, :ncm)

  class Attachment
    def initialize(content)
      @content = content
    end

    def attached?
      !@content.nil?
    end

    def download
      @content
    end

    def filename
      "nfe.xml"
    end
  end

  XmlFile = Struct.new(:id, :compra_id, :empresa, :pessoa, :file)

  def test_produto_sem_origem_com_origem_unica_fica_elegivel
    resultado, produto = executar(xmls: [xml(origem: "1")])

    assert_equal :atualizar, resultado[:produtos][produto.cod_produto][:status]
    assert_nil produto.origem
  end

  def test_produto_ja_com_origem_nao_e_alterado
    produto = Product.new(50, "Produto 50", "0")
    resultado, = executar(xmls: [xml(origem: "1")], produto: produto, apply: true)

    assert_equal :atualizado, resultado[:produtos][50][:status]
    assert_equal "0", produto.origem
    assert_equal :divergencia_cadastro, resultado[:produtos][50][:campos][:origem][:acao]
  end

  def test_apply_atualiza_produto_sem_origem
    resultado, produto = executar(xmls: [xml(origem: "1")], apply: true)

    assert_equal :atualizado, resultado[:produtos][produto.cod_produto][:status]
    assert_equal "1", produto.origem
    assert_equal "12345678", produto.ncm
    assert_equal "1234567", produto.cest
    assert_equal "7891234567895", produto.gtin
    assert_equal "UN", produto.ucom
    assert_equal 5102, produto.cfop
    assert_equal "6102", resultado[:produtos][produto.cod_produto][:cfop_xml]
  end

  def test_origens_diferentes_geram_conflito
    resultado, produto = executar(xmls: [
      xml(origem: "1", date: "2026-05-15T10:00:00-03:00"),
      xml(origem: "2", date: "2026-09-10T10:00:00-03:00")
    ], apply: true)

    dados = resultado[:produtos][produto.cod_produto]
    assert_equal :atualizado, dados[:status]
    assert_equal "2", produto.origem
    assert_equal({ "1" => 1, "2" => 1 }, dados[:conflitos_historicos][:origem][:valores])
    assert_equal "2", dados[:conflitos_historicos][:origem][:referencia]
    assert_equal 1, dados[:conflitos_historicos][:origem][:quantidade_alteracoes_antigas]
    assert dados[:conflitos_historicos][:origem][:uma_alteracao_antiga]
    refute dados[:conflitos_historicos][:origem][:conflito_valores_data_mais_recente]
  end

  def test_produto_sem_mapeamento_fica_nao_encontrado
    resultado, produto = executar(xmls: [xml(origem: "1")], mappings: [], apply: true)

    assert_equal 1, resultado[:nao_encontrados].size
    assert_nil produto.origem
    detalhe = resultado[:nao_encontrados].values.first[:ocorrencias].first
    assert_equal "ABC", detalhe[:cprod]
    assert_equal "7891234567895", detalhe[:gtin]
    assert_equal "Produto 50", detalhe[:nome_xml]
    assert_equal "12345678", detalhe[:ncm]
    assert_equal "1234567", detalhe[:cest]
    assert_equal "12345678901234567890123456789012345678901234", detalhe[:chave_nf]
  end

  def test_xml_invalido_e_contabilizado_sem_processar_itens
    resultado, = executar(xmls: ["<NFe><infNFe>"])

    assert_equal 1, resultado[:xmls_invalidos]
    assert_empty resultado[:produtos]
  end

  def test_xml_ausente_e_invalido
    resultado, = executar(xmls: [nil])

    assert_equal 1, resultado[:xmls_invalidos]
    assert_match "ausente", resultado[:falhas_xml].first[:motivo]
  end

  def test_xml_destinado_a_outra_empresa_nao_processa_itens
    conteudo = xml(origem: "1").sub("22222222000122", "33333333000133")
    resultado, = executar(xmls: [conteudo])

    assert_equal 1, resultado[:xmls_invalidos]
    assert_empty resultado[:produtos]
  end

  def test_tpnf_saida_vinculado_a_compra_e_processado_sem_alerta
    conteudo = xml(origem: "1").sub("<tpNF>0</tpNF>", "<tpNF>1</tpNF>")
    resultado, produto = executar(xmls: [conteudo])

    assert_equal 1, resultado[:xmls_validos]
    assert_equal :atualizar, resultado[:produtos][produto.cod_produto][:status]
    refute resultado.key?(:xmls_tpnf_saida)
  end

  def test_compra_cancelada_e_ignorada
    resultado, = executar(xmls: [xml(origem: "1")], compra_cancelada: true)

    assert_equal 1, resultado[:xmls_ignorados]
    assert_empty resultado[:produtos]
  end

  def test_origem_invalida_nao_deixa_produto_elegivel
    resultado, produto = executar(xmls: [xml(origem: "9")])

    assert_equal :invalido, resultado[:produtos][produto.cod_produto][:campos][:origem][:validacao]
    assert_nil produto.origem
  end

  def test_multiplas_notas_com_mesma_origem_deixam_produto_elegivel
    resultado, produto = executar(xmls: [xml(origem: "1"), xml(origem: "1")])

    assert_equal :atualizar, resultado[:produtos][produto.cod_produto][:status]
    assert_equal 2, resultado[:produtos][produto.cod_produto][:ocorrencias].size
    assert_empty resultado[:produtos][produto.cod_produto][:conflitos_historicos]
  end

  def test_ncm_invalido_nao_e_sugerido
    resultado, = executar(xmls: [xml(origem: "1", ncm: "1234")])

    assert_equal :invalido, resultado[:produtos][50][:campos][:ncm][:validacao]
    assert_nil resultado[:produtos][50][:campos][:ncm][:sugerido]
  end

  def test_cest_invalido_nao_e_sugerido
    resultado, = executar(xmls: [xml(origem: "1", cest: "123")])

    assert_equal :invalido, resultado[:produtos][50][:campos][:cest][:validacao]
    assert_nil resultado[:produtos][50][:campos][:cest][:sugerido]
  end

  def test_gtin_invalido_nao_e_sugerido
    resultado, = executar(xmls: [xml(origem: "1", gtin: "7891234567890")])

    assert_equal :invalido, resultado[:produtos][50][:campos][:gtin][:validacao]
    assert_nil resultado[:produtos][50][:campos][:gtin][:sugerido]
  end

  def test_cEAN_sem_gtin_usa_cEANTrib_valido
    resultado, = executar(xmls: [xml(origem: "1", gtin: "SEM GTIN", gtin_trib: "7891234567895")])

    assert_equal "7891234567895", resultado[:produtos][50][:campos][:gtin][:sugerido]
    assert_equal :valido, resultado[:produtos][50][:campos][:gtin][:validacao]
  end

  def test_ucom_invalida_nao_e_sugerida
    resultado, = executar(xmls: [xml(origem: "1", ucom: "UNIDADE COMPRIDA")])

    assert_equal :invalido, resultado[:produtos][50][:campos][:ucom][:validacao]
    assert_nil resultado[:produtos][50][:campos][:ucom][:sugerido]
  end

  def test_cadastro_igual_e_divergente_sao_classificados_por_campo
    produto = Product.new(50, "Produto 50", "1", "00000000", "1234567", "7891234567895", "CX", 5102)
    resultado, = executar(xmls: [xml(origem: "1")], produto: produto)
    campos = resultado[:produtos][50][:campos]

    assert_equal :ja_correto, campos[:origem][:acao]
    assert_equal :divergencia_cadastro, campos[:ncm][:acao]
    assert_equal :ja_correto, campos[:cest][:acao]
    assert_equal :ja_correto, campos[:gtin][:acao]
    assert_equal :divergencia_cadastro, campos[:ucom][:acao]
    assert_equal 5102, resultado[:produtos][50][:cfop_atual]
    assert_equal "6102", resultado[:produtos][50][:cfop_xml]
  end

  def test_campo_ausente_na_nf_mais_recente_nao_apaga_nem_usa_valor_antigo
    produto = Product.new(50, "Produto 50", nil, nil, "1234567", nil, nil, 5102)
    resultado, = executar(xmls: [
      xml(origem: "1", cest: "1234567", date: "2026-05-15T10:00:00-03:00"),
      xml(origem: "1", cest: "", date: "2026-09-10T10:00:00-03:00")
    ], produto: produto)

    dados = resultado[:produtos][50]
    assert_equal :sem_fonte, dados[:campos][:cest][:acao]
    assert_equal "1234567", produto.cest
    assert_nil dados[:campos][:cest][:sugerido]
    assert_equal({ "1234567" => 1 }, dados[:conflitos_historicos][:cest][:valores])
    assert_nil dados[:conflitos_historicos][:cest][:referencia]
  end

  def test_xml_sem_campo_nao_apaga_cadastro_existente
    produto = Product.new(50, "Produto 50", "1", "12345678", "1234567", "7891234567895", "UN", 5102)
    resultado, = executar(xmls: [xml(origem: "1", ncm: "", cest: "", gtin: "SEM GTIN", ucom: "")], produto: produto, apply: true)

    dados = resultado[:produtos][50]
    assert_equal "12345678", produto.ncm
    assert_equal "1234567", produto.cest
    assert_equal "7891234567895", produto.gtin
    assert_equal "UN", produto.ucom
    assert_equal :sem_fonte, dados[:campos][:ncm][:acao]
    assert_equal :sem_fonte, dados[:campos][:gtin][:acao]
  end

  def test_nota_mais_recente_e_selecionada
    resultado, = executar(xmls: [
      xml(origem: "1", ncm: "94036000", date: "2026-05-15T10:00:00-03:00"),
      xml(origem: "2", ncm: "94032000", date: "2026-09-10T10:00:00-03:00")
    ])
    dados = resultado[:produtos][50]

    assert_equal "2", dados[:campos][:origem][:sugerido]
    assert_equal "94032000", dados[:campos][:ncm][:sugerido]
    assert_equal "2026-09-10", dados[:referencia][:data_emissao].strftime("%Y-%m-%d")
  end

  def test_multiplas_alteracoes_antigas_sao_contadas
    resultado, = executar(xmls: [
      xml(origem: "5", date: "2026-09-10T10:00:00-03:00", key: "3" * 44),
      xml(origem: "0", date: "2026-05-15T10:00:00-03:00", key: "2" * 44),
      xml(origem: "0", date: "2025-01-20T10:00:00-03:00", key: "1" * 44)
    ])

    historico = resultado[:produtos][50][:conflitos_historicos][:origem]
    assert_equal 2, historico[:quantidade_alteracoes_antigas]
    assert historico[:mais_de_uma_alteracao_antiga]
    refute historico[:uma_alteracao_antiga]
    refute historico[:conflito_valores_data_mais_recente]
  end

  def test_empate_de_data_desempata_pela_chave_crescente
    resultado, = executar(xmls: [
      xml(origem: "2", key: "2" * 44),
      xml(origem: "1", key: "1" * 44)
    ])

    assert_equal "1", resultado[:produtos][50][:campos][:origem][:sugerido]
    assert_equal "1" * 44, resultado[:produtos][50][:referencia][:chave_nf]
    historico = resultado[:produtos][50][:conflitos_historicos][:origem]
    assert historico[:conflito_valores_data_mais_recente]
    assert_equal %w[1 2], historico[:valores_data_mais_recente].sort
  end

  def test_conflito_de_gtin_na_data_mais_recente_nao_e_atualizado
    product = Product.new(50, "Produto 50", "1", "12345678", "1234567", nil, "UN", 5102)
    resultado, = executar(xmls: [
      xml(origem: "1", gtin: "7891234567895", date: "2026-09-10T10:00:00-03:00", key: "1" * 44),
      xml(origem: "1", gtin: "4006381333931", date: "2026-09-10T10:00:00-03:00", key: "2" * 44)
    ], produto: product)
    dados = resultado[:produtos][50]

    assert_equal :conflito_nf_mais_recente, dados[:campos][:gtin][:acao]
    assert_nil product.gtin
    assert_equal %w[4006381333931 7891234567895], dados[:conflitos_historicos][:gtin][:valores_data_mais_recente].sort
    refute dados[:elegivel]
  end

  def test_gtin_diferente_somente_em_nf_antiga_nao_bloqueia_atualizacao
    resultado, product = executar(xmls: [
      xml(origem: "1", gtin: "7891234567895", date: "2026-09-10T10:00:00-03:00"),
      xml(origem: "1", gtin: "4006381333931", date: "2025-01-20T10:00:00-03:00")
    ])

    assert_equal :atualizar, resultado[:produtos][50][:campos][:gtin][:acao]
    assert_equal "7891234567895", resultado[:produtos][50][:campos][:gtin][:sugerido]
    assert_nil product.gtin
  end

  def test_dry_run_nao_invoca_persistencia
    invocacoes = 0
    persistor = ->(*) { invocacoes += 1 }

    executar(xmls: [xml(origem: "1")], persistor: persistor)

    assert_equal 0, invocacoes
  end

  def test_falha_durante_apply_marca_rollback
    first = Product.new(50, "Produto 50", nil, nil, nil, nil, nil, 5102)
    second = Product.new(51, "Produto 51", nil, nil, nil, nil, nil, 5102)
    products = [first, second]
    snapshots = products.map(&:to_h)
    calls = 0
    persistor = lambda do |product, values, _context|
      calls += 1
      values.each { |field, value| product.public_send("#{field}=", value) }
      raise "falha simulada" if calls == 2
      { atualizados: values, ja_corretos: {}, divergencias: {} }
    end
    transaction_runner = lambda do |&block|
      begin
        block.call
      rescue StandardError
        products.zip(snapshots).each { |product, values| product.members.each { |member| product[member] = values[member] } }
        raise
      end
    end

    resultado, = executar(
      xmls: [xml(origem: "1", cprod: "ABC"), xml(origem: "1", cprod: "DEF")],
      products: products,
      mappings: ->(cprod, *) { [Mapping.new(cprod == "ABC" ? 50 : 51, nil, nil, nil)] },
      apply: true,
      persistor: persistor,
      transaction_runner: transaction_runner
    )

    assert_equal :rollback, resultado[:produtos][50][:status]
    assert_equal :rollback, resultado[:produtos][51][:status]
    assert_nil first.origem
    assert_nil second.origem
    assert_match "falha simulada", resultado[:erro_transacao]
  end

  def test_mapeamentos_para_produtos_diferentes_ficam_ambiguos
    resultado, = executar(
      xmls: [xml(origem: "1")],
      mappings: [Mapping.new(50, nil, nil, nil), Mapping.new(51, nil, nil, nil)],
      products: [Product.new(50, "Produto 50", nil), Product.new(51, "Produto 51", nil)]
    )

    assert_equal 1, resultado[:vinculos_ambiguos].size
    assert_equal :vinculo_ambiguo, resultado[:produtos][50][:status]
    assert_equal :vinculo_ambiguo, resultado[:produtos][51][:status]
    detalhe = resultado[:vinculos_ambiguos].values.first[:ocorrencias].first
    assert_equal [50, 51], detalhe[:codigos_produto_candidatos]
    assert_match "mais de um produto", detalhe[:motivo_vinculo_ambiguo]
    assert_equal "Produto 50", detalhe[:nome_xml]
    assert_equal "7891234567895", detalhe[:gtin]
    assert_equal "12345678", detalhe[:ncm]
    assert_equal "1234567", detalhe[:cest]
  end

  def test_vinculo_ambiguo_bloqueia_produto_encontrado_em_outro_item
    produto = Product.new(50, "Produto 50", nil)
    resultado, = executar(
      xmls: [xml(origem: "1"), xml(origem: "1")],
      mappings: [Mapping.new(50, nil, nil, nil), Mapping.new(51, nil, nil, nil)],
      products: [produto, Product.new(51, "Produto 51", nil)]
    )

    assert_equal :vinculo_ambiguo, resultado[:produtos][50][:status]
    refute resultado[:produtos][50][:elegivel]
  end

  private

  def executar(xmls:, produto: Product.new(50, "Produto 50", nil, nil, nil, nil, nil, 5102), mappings: [Mapping.new(50, nil, nil, nil)], products: nil, apply: false, compra_cancelada: false, persistor: nil, transaction_runner: ->(&block) { block.call })
    company = Company.new(3, "22222222000122")
    supplier = Supplier.new(20, "11111111000111", "Fornecedor", "Fornecedor")
    files = xmls.each_with_index.map do |content, index|
      XmlFile.new(index + 1, 100 + index, company, supplier, Attachment.new(content)).tap do |file|
        file.define_singleton_method(:compra) do
          Struct.new(:cancelada?).new(compra_cancelada)
        end
      end
    end
    products ||= [produto]
    persistor ||= lambda do |record, values, _context|
      values.each { |field, value| record.public_send("#{field}=", value) }
      { atualizados: values, ja_corretos: {}, divergencias: {} }
    end
    service = Fiscal::OrigemProdutoNfeService.new(
      xml_files: files,
      mappings_for: ->(cprod, supplier_id) { mappings.respond_to?(:call) ? mappings.call(cprod, supplier_id) : mappings },
      find_product: ->(cod_produto) { products.find { |record| record.cod_produto == cod_produto } },
      persistor: persistor,
      transaction_runner: transaction_runner
    )

    [service.executar(apply: apply), produto]
  end

  def xml(origem:, ncm: "12345678", cest: "1234567", gtin: "7891234567895", gtin_trib: "SEM GTIN", ucom: "UN", cfop: "6102", date: "2026-09-10T10:00:00-03:00", key: "12345678901234567890123456789012345678901234", cprod: "ABC")
    <<~XML
      <NFe>
        <infNFe Id="NFe#{key}">
          <ide><dhEmi>#{date}</dhEmi><tpNF>0</tpNF><nNF>123</nNF></ide>
          <emit><CNPJ>11111111000111</CNPJ><xNome>Fornecedor</xNome></emit>
          <dest><CNPJ>22222222000122</CNPJ></dest>
          <det nItem="1">
            <prod><cProd>#{cprod}</cProd><xProd>Produto 50</xProd><NCM>#{ncm}</NCM><CEST>#{cest}</CEST><cEAN>#{gtin}</cEAN><cEANTrib>#{gtin_trib}</cEANTrib><uCom>#{ucom}</uCom><CFOP>#{cfop}</CFOP></prod>
            <imposto><ICMS><ICMS00><orig>#{origem}</orig></ICMS00></ICMS></imposto>
          </det>
        </infNFe>
      </NFe>
    XML
  end
end