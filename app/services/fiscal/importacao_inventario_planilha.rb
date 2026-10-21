require "csv"
require "bigdecimal"

module Fiscal
  # Parser da planilha PADRAO de inventario fiscal. Foco no minimo necessario:
  #   Codigo      (obrigatorio) = cod_produto do sistema
  #   Quantidade  (obrigatorio) = saldo fiscal (inventario)
  #   NCM         (opcional)    = NCM; se vier, limpamos p/ 8 digitos
  #   Produto     (opcional)    = nome (usado so no cadastro de produto novo)
  #
  # Aceita colunas extras na planilha (Data, CNPJ, Preco, etc.) — sao ignoradas.
  # Aceita CSV e XLSX. Reconhece varios apelidos de cabecalho (pt-BR), sem acento.
  class ImportacaoInventarioPlanilha
    # Obrigatorias: nome, ncm, quantidade.
    # Opcionais: codigo (se vazio, gera no cadastro), unidade_medida,
    #            valor_unitario (custo) e valor_venda.
    COLUNAS = {
      codigo:         %w[codigo codigoproduto codigodoproduto codproduto],
      nome:           %w[nome produto nomedoproduto descricao],
      ncm:            %w[ncm],
      quantidade:     %w[quantidade qtd qtde estoque saldofiscal saldo],
      unidade_medida: %w[unidademedida unidadedemedida unidade ucom unmedida un],
      valor_unitario: %w[valorunitario valorunit custo valorcusto precocusto precodecompra],
      valor_venda:    %w[valorvenda precovenda valordevenda]
    }.freeze

    def initialize(path:, filename:)
      @path = path
      @extension = File.extname(filename.to_s).downcase
    end

    def parse
      rows = case @extension
      when ".csv"          then parse_csv
      when ".xlsx", ".xlsm" then parse_excel
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
      CSV.parse(contents, headers: false, col_sep: delimiter).map(&:to_a)
    end

    def parse_excel
      require "roo"
      spreadsheet = Roo::Spreadsheet.open(@path, extension: @extension.delete("."))
      sheet = spreadsheet.sheet(0)
      (1..sheet.last_row.to_i).map { |n| sheet.row(n) }
    rescue LoadError
      raise ArgumentError, "O servidor ainda não carregou o leitor XLSX. Reinicie o Rails e tente novamente."
    end

    def parse_rows(rows)
      header_index, cols = localizar_cabecalho(rows)
      (header_index + 1...rows.length).filter_map do |i|
        row = rows[i]
        next if row.nil? || row.all? { |v| v.to_s.strip.empty? }

        valores = cols.transform_values { |idx| idx ? row[idx] : nil }
        codigo = valores[:codigo].to_s.strip
        nome = valores[:nome].to_s.strip
        quantidade = parse_quantidade(valores[:quantidade])
        ncm = limpar_ncm(valores[:ncm])
        unidade = valores[:unidade_medida].to_s.strip
        valor_unitario = parse_quantidade(valores[:valor_unitario]) # custo (opcional)
        valor_venda = parse_quantidade(valores[:valor_venda])       # venda (opcional)

        erros = []
        # Codigo e OPCIONAL: vazio -> gera no cadastro. Nao-numerico (ex.:
        # "01100151-henn", assistencia) nao casa com cod_produto -> marcamos,
        # mas o classificador decide o tratamento (cadastro/erro).
        erros << "Código não numérico" if codigo.present? && !codigo.match?(/\A\d+\z/)
        erros << "Nome vazio" if nome.blank?
        erros << "NCM vazio" if ncm.blank?
        erros << "NCM deve ter 8 dígitos" if ncm.present? && !ncm.match?(/\A\d{8}\z/)
        erros << "Quantidade inválida" if quantidade.nil?
        erros << "Quantidade negativa" if quantidade&.negative?
        erros << "Quantidade com mais de 2 casas" if quantidade && quantidade.scale > 2

        {
          linha_planilha: i + 1,
          codigo: codigo,
          nome: nome,
          ncm: ncm,
          unidade_medida: unidade,
          quantidade: quantidade,
          valor_unitario: valor_unitario,
          valor_venda: valor_venda,
          erros: erros
        }
      end
    end

    def localizar_cabecalho(rows)
      rows.each_with_index do |row, i|
        headers = Array(row).map { |v| normalizar(v) }
        idx = COLUNAS.transform_values { |aliases| headers.index { |h| aliases.include?(h) } }
        # Obrigatorias: codigo, nome, ncm, quantidade (valor_* sao opcionais).
        return [i, idx] if idx[:nome] && idx[:ncm] && idx[:quantidade]
      end
      raise ArgumentError, "Cabeçalho precisa conter as colunas: Nome, NCM e Quantidade (Codigo é opcional)."
    end

    def normalizar(value)
      value.to_s.strip.downcase.unicode_normalize(:nfkd).encode("ASCII", replace: "").gsub(/[^a-z0-9]/, "")
    end

    # NCM: remove tudo que nao for digito (a planilha costuma vir com espaco ou
    # ".0" de formatacao). Vazio => nil. Nao forca 8 digitos aqui (valida depois).
    def limpar_ncm(value)
      s = value.to_s.strip
      return nil if s.empty?
      # "94042900.0" (float do Excel) -> tira a parte decimal.
      s = s.sub(/\.\d+\z/, "")
      digitos = s.gsub(/\D/, "")
      digitos.presence
    end

    def parse_quantidade(value)
      return nil if value.nil? || value.to_s.strip.empty?
      return BigDecimal(value.to_s) if value.is_a?(Numeric)

      text = value.to_s.strip.gsub(/\s/, "")
      text = text.gsub(".", "").sub(",", ".") if text.include?(",")
      BigDecimal(text)
    rescue ArgumentError
      nil
    end
  end
end
