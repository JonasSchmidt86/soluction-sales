require "bundler/setup"
require "minitest/autorun"
require "active_support/core_ext/object/blank"
require "csv"
require "tmpdir"
require_relative "../../../app/services/fiscal/origem_produto_nfe_service"
require_relative "../../../app/services/fiscal/origem_produto_nfe_csv_report"

class OrigemProdutoNfeCsvReportTest < Minitest::Test
  Product = Struct.new(:cod_produto, :nome, :origem, :ncm, :cest, :gtin, :ucom, :cfop)

  def test_csv_inclui_resumos_divergencias_e_historico
    product = Product.new(123, "Produto exemplo", "5", "94036000", "2806100", nil, "UN", 5102)
    reference = {
      data_emissao: Time.iso8601("2026-09-10T10:00:00-03:00"),
      chave_nf: "1" * 44, numero_nf: "10", fornecedor: "Fornecedor", cprod: "ABC",
      nitem: "1", cfop: "6102", valores_validos: { origem: "5" }
    }
    old_occurrence = { data_emissao: Time.iso8601("2025-01-20T10:00:00-03:00"), valores_validos: { origem: "0" } }
    product_with_ambiguous_link = Product.new(124, "Produto com candidato ambíguo", "5", "94036000", "2806100", nil, "UN", 5102)
    report = {
      produtos: {
        123 => {
          produto: product,
          ocorrencias: [reference, old_occurrence],
          vinculos_ambiguos: [],
          cfop_atual: 5102,
          campos: {
            gtin: { acao: :divergencia_cadastro, atual: "", sugerido: "7891234567895", fonte: reference }
          },
          conflitos_historicos: {
            origem: {
              fonte: reference,
              referencia: "5",
              valores: { "5" => 1, "0" => 1 },
              ocorrencias: { "5" => [reference], "0" => [old_occurrence] },
              alteracoes_antigas: [old_occurrence],
              quantidade_alteracoes_antigas: 1,
              uma_alteracao_antiga: true,
              mais_de_uma_alteracao_antiga: false,
              valores_data_mais_recente: ["5"],
              conflito_valores_data_mais_recente: false
            }
          }
        },
        124 => {
          produto: product_with_ambiguous_link,
          ocorrencias: [reference, old_occurrence],
          vinculos_ambiguos: [{ cprod: "XYZ" }],
          cfop_atual: 5102,
          campos: {
            ncm: { acao: :divergencia_cadastro, atual: "94032000", sugerido: "94036000", fonte: reference }
          },
          conflitos_historicos: {
            origem: {
              fonte: reference,
              referencia: "5",
              valores: { "5" => 1, "0" => 1 },
              ocorrencias: { "5" => [reference], "0" => [old_occurrence] },
              alteracoes_antigas: [old_occurrence],
              quantidade_alteracoes_antigas: 1,
              uma_alteracao_antiga: true,
              mais_de_uma_alteracao_antiga: false,
              valores_data_mais_recente: ["5"],
              conflito_valores_data_mais_recente: false
            }
          }
        }
      }
    }

    Dir.mktmpdir do |directory|
      path = Fiscal::OrigemProdutoNfeCsvReport.new(report).write(path: File.join(directory, "auditoria.csv"))
      rows = CSV.read(path, headers: true, encoding: "bom|utf-8")

      summary = rows.find { |row| row["tipo_registro"] == "RESUMO_CAMPO" && row["campo"] == "gtin" }
      ambiguous_divergence_summary = rows.find { |row| row["tipo_registro"] == "RESUMO_CAMPO" && row["campo"] == "ncm" }
      historical_summary = rows.find { |row| row["tipo_registro"] == "RESUMO_HISTORICO" && row["campo"] == "origem" }
      total_history_summary = rows.find { |row| row["tipo_registro"] == "RESUMO_HISTORICO_TOTAL" }
      divergence = rows.find { |row| row["tipo_registro"] == "DIVERGENCIA_CADASTRO" }
      historical = rows.find { |row| row["tipo_registro"] == "DIVERGENCIA_HISTORICA" }
      ambiguous_history = rows.find { |row| row["tipo_registro"] == "DIVERGENCIA_HISTORICA" && row["cod_produto"] == "124" }
      ambiguous_divergence = rows.find { |row| row["tipo_registro"] == "DIVERGENCIA_CADASTRO_COM_VINCULO_AMBIGUO" }

      assert_equal "1", summary["quantidade_divergencia_cadastro"]
      assert_equal "0", summary["quantidade_conflito_nf_mais_recente"]
      assert_equal "1", ambiguous_divergence_summary["quantidade_divergencia_cadastro_vinculo_ambiguo"]
      assert_equal "2", historical_summary["quantidade_produtos_com_divergencia_historica"]
      assert_equal "4", historical_summary["quantidade_ocorrencias_historicas"]
      assert_equal "2", historical_summary["apenas_uma_alteracao_antiga"]
      assert_equal "0", historical_summary["mais_de_uma_alteracao_antiga"]
      assert_equal "2", total_history_summary["quantidade_produtos_com_divergencia_historica"]
      assert_equal "123", divergence["cod_produto"]
      assert_equal "7891234567895", divergence["valor_sugerido"]
      assert_equal "true", historical["apenas_uma_alteracao_antiga"]
      assert_equal "5=1; 0=1", historical["valores_historicos"]
      assert_equal "true", ambiguous_history["possui_vinculo_ambiguo"]
      assert_equal "124", ambiguous_divergence["cod_produto"]
      assert_match "NÃO ATUALIZAR", ambiguous_divergence["acao"]
    end
  end
end