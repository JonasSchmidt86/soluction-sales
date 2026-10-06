require "nokogiri"

module Fiscal
  # Extrai de uma COMPRA (nota de entrada) os dados necessarios para montar a
  # NF-e de DEVOLUCAO espelhando os impostos destacados na nota original.
  #
  # Fonte primaria: o XML da nota de compra (compra.xml_file), que tem todos os
  # impostos por item. Fallback (sem XML): usa itemcompra (valores agregados).
  #
  # Uso:
  #   ext = Fiscal::DevolucaoCompraExtractor.new(compra)
  #   ext.chave_referencia   # => "4126..." (44 dig) ou nil
  #   ext.itens              # => [{ cod_produto:, cod_cor:, descricao:, ncm:, cfop:,
  #                          #       quantidade:, valor_unitario:, valor_total:,
  #                          #       origem:, imposto: { icms:{...}, ipi:{...}, pis:{...}, cofins:{...} } }, ...]
  class DevolucaoCompraExtractor
    def initialize(compra)
      @compra = compra
      @doc = carregar_xml
    end

    # Chave de acesso (44 digitos) da NF de compra, para o NFReferencia.
    # Fontes, em ordem de confiabilidade:
    #   1) filename do blob do XML ("NFe<44>") — mais confiavel;
    #   2) atributo Id de infNFe dentro do XML;
    #   3) xml_file.name (as vezes guarda a chave, as vezes o nome do fornecedor).
    def chave_referencia
      xf = @compra.xml_file

      if xf&.file&.attached?
        d = xf.file.filename.to_s.gsub(/\D/, "")
        return d if d.length == 44
      end

      if @doc
        id = @doc.at_xpath('//*[local-name()="infNFe"]')&.[]("Id").to_s
        d = id.gsub(/\D/, "")
        return d if d.length == 44
      end

      d = xf&.name.to_s.gsub(/\D/, "")
      return d if d.length == 44

      nil
    end

    def tem_xml?
      !@doc.nil?
    end

    # Itens da devolucao espelhando a entrada. Casa cada <det> do XML com o
    # itemcompra correspondente (pela ordem/produto) para trazer cod_produto/cod_cor.
    def itens
      return itens_do_xml if @doc
      itens_do_itemcompra
    end

    private

    def carregar_xml
      path = @compra.xml_file&.local_file_path
      return nil unless path && File.exist?(path)
      Nokogiri::XML(File.read(path, encoding: "UTF-8"))
    rescue => e
      Rails.logger.error("[DevolucaoCompraExtractor] falha ao ler XML: #{e.class} - #{e.message}")
      nil
    end

    # ---- A partir do XML (espelho fiel dos impostos) ----
    def itens_do_xml
      dets = @doc.xpath('//*[local-name()="det"]')
      itenscompra = @compra.itenscompra.reject(&:cancelado?).to_a

      dets.each_with_index.map do |det, i|
        prod = det.at_xpath('.//*[local-name()="prod"]')
        imp  = det.at_xpath('.//*[local-name()="imposto"]')
        ic   = itenscompra[i] # casa pela ordem (det 1 = item 1)

        quantidade = txt(prod, "qCom").to_d
        vl_unit    = txt(prod, "vUnCom").to_d
        vl_total   = txt(prod, "vProd").to_d

        {
          cod_produto:    ic&.cod_produto,
          cod_cor:        ic&.cod_cor,
          descricao:      txt(prod, "xProd"),
          cod_produto_emissor: txt(prod, "cProd"),
          ncm:            txt(prod, "NCM"),
          cfop_original:  txt(prod, "CFOP"),
          ean:            txt(prod, "cEAN"),
          unidade:        txt(prod, "uCom").presence || "UN",
          quantidade:          quantidade,
          # Quantidade original da nota de entrada — usada para recalcular os
          # impostos proporcionalmente quando a devolucao for parcial. NAO deve
          # ser editada pelo controller.
          quantidade_original: quantidade,
          valor_unitario: vl_unit,
          valor_total:    (vl_total.nonzero? || (quantidade * vl_unit)).to_d,
          origem:         extrair_origem(imp),
          imposto:        extrair_imposto(imp)
        }
      end
    end

    # ICMS pode vir em varios grupos (ICMS00/10/.../ICMSSN101/102/500...).
    # Pegamos o primeiro grupo filho de <ICMS> e lemos as tags presentes.
    def extrair_imposto(imp)
      return {} if imp.nil?

      icms_grp = imp.at_xpath('.//*[local-name()="ICMS"]/*')
      ipi_grp  = imp.at_xpath('.//*[local-name()="IPI"]//*[local-name()="IPITrib"]') ||
                 imp.at_xpath('.//*[local-name()="IPI"]/*')
      pis_grp  = imp.at_xpath('.//*[local-name()="PIS"]/*')
      cof_grp  = imp.at_xpath('.//*[local-name()="COFINS"]/*')

      {
        icms:   extrair_icms(icms_grp),
        ipi:    extrair_ipi(ipi_grp),
        pis:    extrair_pis_cofins(pis_grp),
        cofins: extrair_pis_cofins(cof_grp)
      }.reject { |_, v| v.blank? }
    end

    def extrair_icms(grp)
      return {} if grp.nil?
      {
        cst:          txt(grp, "CST").presence || txt(grp, "CSOSN").presence,
        base_calculo: txt(grp, "vBC").to_d,
        aliquota:     txt(grp, "pICMS").to_d,
        valor:        txt(grp, "vICMS").to_d,
        base_st:      txt(grp, "vBCST").to_d,
        valor_st:     txt(grp, "vICMSST").to_d
      }.reject { |_, v| v.respond_to?(:zero?) ? false : v.blank? }
    end

    def extrair_ipi(grp)
      return {} if grp.nil?
      {
        cst:      txt(grp, "CST").presence,
        aliquota: txt(grp, "pIPI").to_d,
        valor:    txt(grp, "vIPI").to_d
      }.reject { |_, v| v.respond_to?(:zero?) ? false : v.blank? }
    end

    def extrair_pis_cofins(grp)
      return {} if grp.nil?
      {
        cst:          txt(grp, "CST").presence,
        base_calculo: txt(grp, "vBC").to_d,
        aliquota:     txt(grp, "pPIS").presence&.to_d || txt(grp, "pCOFINS").to_d,
        valor:        txt(grp, "vPIS").presence&.to_d || txt(grp, "vCOFINS").to_d
      }.reject { |_, v| v.respond_to?(:zero?) ? false : v.blank? }
    end

    def extrair_origem(imp)
      imp&.at_xpath('.//*[local-name()="orig"]')&.text.to_s.strip.presence
    end

    # ---- Fallback sem XML: usa os valores agregados do itemcompra ----
    def itens_do_itemcompra
      @compra.itenscompra.reject(&:cancelado?).map do |ic|
        qtd = ic.quantidade.to_d
        vu  = ic.valorunitario.to_d
        {
          cod_produto:    ic.cod_produto,
          cod_cor:        ic.cod_cor,
          descricao:      ic.produto&.nome,
          ncm:            ic.produto&.ncm,
          cfop_original:  ic.produto&.cfop,
          unidade:        "UN",
          quantidade:          qtd,
          quantidade_original: qtd,
          valor_unitario: vu,
          valor_total:    (qtd * vu),
          origem:         ic.produto&.origem,
          imposto: {
            icms: { valor: ic.icms.to_d },
            ipi:  { valor: ic.ipi.to_d },
            st:   { valor: ic.valorst.to_d }
          }.reject { |_, v| v[:valor].to_d.zero? }
        }
      end
    end

    def txt(node, tag)
      return nil if node.nil?
      node.at_xpath(".//*[local-name()=\"#{tag}\"]")&.text&.strip
    end
  end
end
