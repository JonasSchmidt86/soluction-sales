require "csv"
require "bigdecimal"

module Fiscal
  class ImportacaoEstoquePlanilha
    COLUNAS = {
      codigo: %w[codigoproduto codigodoproduto codproduto codigo produto],
      nome: %w[nome nomedoproduto produto descricao],
      ncm: %w[ncm],
      unidade_medida: %w[unidademedida unidadedemedida unidade ucom],
      quantidade: %w[quantidade qtd estoque saldofiscal]
    }.freeze

    def initialize(path:, filename:)
      @path = path
      @extension = File.extname(filename.to_s).downcase
    end

    def parse
      rows = case @extension
      when ".csv"
        parse_csv
      when ".xlsx", ".xlsm"
        parse_excel
      else
        raise ArgumentError, "Formato não suportado. Envie CSV ou XLSX."
      end

      parse_rows(rows)
    rescue CSV::MalformedCSVError => e
      raise ArgumentError, "CSV inválido: #{e.message}"
    rescue StandardError => e
      erro_planilha = (defined?(Roo::Error) && e.is_a?(Roo::Error)) ||
                      (defined?(Zip::Error) && e.is_a?(Zip::Error))
      raise ArgumentError, "Não foi possível ler a planilha: #{e.message}" if erro_planilha
      raise
    end

    private

    def parse_csv
      contents = File.read(@path, encoding: "bom|utf-8")
      first_line = contents.lines.find { |line| line.strip.present? }.to_s
      delimiter = first_line.count(";") > first_line.count(",") ? ";" : ","
      table = CSV.parse(contents, headers: false, col_sep: delimiter)
      table.map(&:to_a)
    end

    def parse_excel
      require "roo"
      spreadsheet = Roo::Spreadsheet.open(@path, extension: @extension.delete("."))
      sheet = spreadsheet.sheet(0)
      (1..sheet.last_row.to_i).map { |row_number| sheet.row(row_number) }
    rescue LoadError
      raise ArgumentError, "O servidor ainda não carregou o leitor XLSX. Reinicie o Rails e tente novamente."
    end

    def parse_rows(rows)
      header_index, column_indexes = localizar_cabecalho(rows)
      (header_index + 1...rows.length).filter_map do |row_index|
        row = rows[row_index]
        next if row.nil? || row.all? { |value| value.to_s.strip.empty? }

        values = column_indexes.transform_values { |column_index| column_index ? row[column_index] : nil }
        codigo = values[:codigo].to_s.strip
        quantidade = parse_quantidade(values[:quantidade])
        erros = []
        erros << "Código do produto vazio" if codigo.blank?
        erros << "Quantidade inválida" if quantidade.nil?
        erros << "Quantidade não pode ser negativa" if quantidade&.negative?
        erros << "Quantidade aceita no máximo 2 casas decimais" if quantidade && quantidade.scale > 2

        {
          linha_planilha: row_index + 1,
          codigo: codigo,
          nome: values[:nome].to_s.strip,
          ncm: values[:ncm].to_s.strip,
          unidade_medida: values[:unidade_medida].to_s.strip,
          quantidade: quantidade,
          erros: erros
        }
      end
    end

    def localizar_cabecalho(rows)
      rows.each_with_index do |row, row_index|
        headers = Array(row).map { |value| normalizar_cabecalho(value) }
        indexes = COLUNAS.each_with_object({}) do |(column, aliases), result|
          result[column] = headers.index { |header| aliases.include?(header) }
        end
        return [row_index, indexes] if indexes[:codigo] && indexes[:quantidade]
      end

      raise ArgumentError, "Cabeçalho precisa conter Código Produto e Quantidade."
    end

    def normalizar_cabecalho(value)
      value.to_s.strip.downcase.unicode_normalize(:nfkd).encode("ASCII", replace: "").gsub(/[^a-z0-9]/, "")
    end

    def parse_quantidade(value)
      return nil if value.nil? || value.to_s.strip.empty?
      return BigDecimal(value.to_s) if value.is_a?(Numeric)

      text = value.to_s.strip.gsub(/\s/, "")
      if text.include?(",")
        text = text.gsub(".", "").sub(",", ".")
      end
      BigDecimal(text)
    rescue ArgumentError
      nil
    end
  end
end