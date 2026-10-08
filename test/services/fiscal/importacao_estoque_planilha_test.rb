require "bundler/setup"
require "minitest/autorun"
require "active_support/core_ext/object/blank"
require "tmpdir"
require_relative "../../../app/services/fiscal/importacao_estoque_planilha"

class ImportacaoEstoquePlanilhaTest < Minitest::Test
  def test_le_cabecalho_com_acentos_e_quantidade_decimal_brasileira
    linhas = parse_csv(<<~CSV)
      Código Produto;Nome do Produto;NCM;Unidade de Medida;quantidade
      123;Produto A;94036000;UN;1.234,50
    CSV

    assert_equal "123", linhas.first[:codigo]
    assert_equal "Produto A", linhas.first[:nome]
    assert_equal "94036000", linhas.first[:ncm]
    assert_equal "UN", linhas.first[:unidade_medida]
    assert_equal BigDecimal("1234.50"), linhas.first[:quantidade]
    assert_empty linhas.first[:erros]
  end

  def test_marca_codigo_ausente_quantidade_invalida_e_negativa
    linhas = parse_csv(<<~CSV)
      codigo,quantidade
      ,abc
      124,-2
    CSV

    assert_includes linhas[0][:erros], "Código do produto vazio"
    assert_includes linhas[0][:erros], "Quantidade inválida"
    assert_includes linhas[1][:erros], "Quantidade não pode ser negativa"
  end

  def test_rejeita_planilha_sem_colunas_obrigatorias
    error = assert_raises(ArgumentError) { parse_csv("nome,ncm\nProduto,94036000\n") }

    assert_match "Código Produto e Quantidade", error.message
  end

  def test_rejeita_quantidade_com_mais_de_duas_casas_decimais
    linha = parse_csv("codigo,quantidade\n125,1.234\n").first

    assert_includes linha[:erros], "Quantidade aceita no máximo 2 casas decimais"
  end

  private

  def parse_csv(contents)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "estoque.csv")
      File.write(path, contents)
      Fiscal::ImportacaoEstoquePlanilha.new(path: path, filename: "estoque.csv").parse
    end
  end
end