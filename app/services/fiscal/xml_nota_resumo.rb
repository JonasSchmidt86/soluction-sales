module Fiscal
  # Extrai o RESUMO de uma NF-e a partir do seu XML (string). Usado pelo painel
  # de Notas Recebidas e pelo recebimento automatico. Tolera NF-e e NFC-e;
  # usa local-name() para ignorar namespaces.
  #
  # Uso:
  #   r = Fiscal::XmlNotaResumo.new(xml_string)
  #   r.chave, r.emitente_nome, r.transportadora_cnpj, ...
  class XmlNotaResumo
    def initialize(xml_string)
      @doc = Nokogiri::XML(xml_string.to_s)
    end

    def valido?
      @doc.at_xpath('//*[local-name()="infNFe"]').present?
    end

    # Chave de acesso (44 digitos), do atributo Id de infNFe ("NFe<44>").
    def chave
      id = @doc.at_xpath('//*[local-name()="infNFe"]')&.[]("Id").to_s
      d = id.gsub(/\D/, "")
      d.length == 44 ? d : nil
    end

    def modelo;   txt('//*[local-name()="ide"]/*[local-name()="mod"]')&.to_i; end
    def numero;   txt('//*[local-name()="ide"]/*[local-name()="nNF"]'); end
    def serie;    txt('//*[local-name()="ide"]/*[local-name()="serie"]'); end
    def natureza; txt('//*[local-name()="ide"]/*[local-name()="natOp"]'); end
    def tipo_nf;  txt('//*[local-name()="ide"]/*[local-name()="tpNF"]')&.to_i; end # 0 entrada / 1 saida

    def data_emissao
      raw = txt('//*[local-name()="ide"]/*[local-name()="dhEmi"]') ||
            txt('//*[local-name()="ide"]/*[local-name()="dEmi"]')
      Time.parse(raw) if raw.present?
    rescue ArgumentError
      nil
    end

    def valor_total
      txt('//*[local-name()="ICMSTot"]/*[local-name()="vNF"]')&.to_d
    end

    # ---- Emitente (fornecedor) ----
    def emitente_cnpj
      digitos(txt('//*[local-name()="emit"]/*[local-name()="CNPJ"]') ||
              txt('//*[local-name()="emit"]/*[local-name()="CPF"]'))
    end

    def emitente_nome
      txt('//*[local-name()="emit"]/*[local-name()="xNome"]')
    end

    def emitente_ie;    txt('//*[local-name()="emit"]/*[local-name()="IE"]'); end
    def emitente_fant;  txt('//*[local-name()="emit"]/*[local-name()="xFant"]'); end

    # Endereco do emitente (para cadastrar o fornecedor novo).
    def emitente_endereco
      e = @doc.at_xpath('//*[local-name()="emit"]/*[local-name()="enderEmit"]')
      return {} if e.nil?
      {
        cep:        digitos(sub(e, "CEP")),
        logradouro: sub(e, "xLgr"),
        numero:     sub(e, "nro"),
        bairro:     sub(e, "xBairro"),
        municipio:  sub(e, "xMun"),
        uf:         sub(e, "UF"),
        cod_municipio: sub(e, "cMun"),
        fone:       sub(e, "fone")
      }
    end

    # ---- Transportadora ----
    def transportadora_nome
      txt('//*[local-name()="transp"]/*[local-name()="transporta"]/*[local-name()="xNome"]')
    end

    def transportadora_cnpj
      digitos(txt('//*[local-name()="transp"]/*[local-name()="transporta"]/*[local-name()="CNPJ"]') ||
              txt('//*[local-name()="transp"]/*[local-name()="transporta"]/*[local-name()="CPF"]'))
    end

    private

    def txt(xpath)
      @doc.at_xpath(xpath)&.text.presence
    end

    def sub(node, tag)
      node.at_xpath(".//*[local-name()=\"#{tag}\"]")&.text.presence
    end

    def digitos(v)
      v.to_s.gsub(/\D/, "").presence
    end
  end
end
