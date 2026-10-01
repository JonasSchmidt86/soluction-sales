require "net/http"
require "json"
require "uri"

# Adapter concreto para a API do Brasil NFe (API 2.0).
# Implementa o contrato usado pelo FiscalService. Recebe um "documento neutro"
# (Hash com chaves simbólicas) e traduz para o payload da API do Brasil NFe.
#
# Doc: https://www.brasilnfe.com.br/api/nf-e-e-nfc-e
# Endpoint base: https://api.brasilnfe.com.br/services/fiscal
# Auth: header "Token: <token da empresa>"
# TipoAmbiente: "2" homologacao / "1" producao (string)
#
# O token NUNCA fica no codigo: vem de Rails.application.credentials.brasilnfe_token
# (ou do fiscal_config, na Parte 3). Numeracao pode ser automatica (nao enviar Serie/Numero).
module Fiscal
  class BrasilNfeAdapter
    BASE_URL = "https://api.brasilnfe.com.br/services/fiscal".freeze

    class ConfiguracaoInvalida < StandardError; end

    attr_reader :ambiente, :token

    # config: FiscalConfig (opcional nesta fase). token: sobrescreve o das credentials.
    def initialize(config: nil, token: nil)
      @config = config
      @ambiente = (config&.producao? ? "1" : "2") # default homologacao
      @token = token || credentials_token
    end

    # ---- Contrato FiscalService ----

    # documento: Hash neutro montado pela camada de emissão (Parte 3).
    # Ex.: { modelo: 55, natureza: "Venda...", consumidor_final: true,
    #        cliente: {...}, produtos: [ { ... , imposto: {...} } ],
    #        pagamentos: [...], finalidade: 1, nf_referencia: [] }
    def emitir(documento)
      payload = montar_payload(documento)
      resposta = post("/EnviarNotaFiscal", payload)
      to_result(resposta)
    end

    # Devolução = emissão com Finalidade 4 + chaves das notas de origem.
    def devolver(documento_origem, itens)
      doc = documento_origem.merge(finalidade: 4)
      doc[:produtos] = itens if itens.present?
      emitir(doc)
    end

    # Cancela uma NF-e/NFC-e autorizada (evento SEFAZ 110111), dentro do prazo.
    # referencia: chave de acesso (44 digitos) da nota a cancelar.
    # justificativa: texto >= 15 caracteres exigido pela SEFAZ.
    #
    # OBS: o nome do endpoint/campos segue a convencao do EnviarNotaFiscal
    # (CancelarNotaFiscal). Confirmar contra a doc 2.0 do Brasil NFe antes de
    # usar em PRODUCAO — em homologacao o retorno valida o formato.
    def cancelar(referencia, justificativa)
      just = justificativa.to_s.strip
      raise ConfiguracaoInvalida, "Chave de acesso ausente para cancelamento" if referencia.blank?
      raise ConfiguracaoInvalida, "Justificativa deve ter ao menos 15 caracteres" if just.length < 15

      payload = {
        "TipoAmbiente" => ambiente,
        "ChaveNF"      => referencia,
        "Justificativa" => just
      }
      resposta = post("/CancelarNotaFiscal", payload)
      to_cancel_result(resposta)
    end

    def carta_correcao(_referencia, _texto)
      nao_implementado(:carta_correcao)
    end

    def inutilizar(**_kwargs)
      nao_implementado(:inutilizar)
    end

    def consultar(_referencia)
      nao_implementado(:consultar)
    end

    private

    def credentials_token
      Rails.application.credentials.brasilnfe_token
    rescue
      nil
    end

    # Monta o corpo do EnviarNotaFiscal a partir do documento neutro.
    # Só inclui o essencial; Serie/Numero/Lote ficam automáticos (não enviados).
    def montar_payload(doc)
      {
        "TipoAmbiente"      => ambiente,
        "ModeloDocumento"   => doc[:modelo] || 55,
        "Finalidade"        => doc[:finalidade] || 1,
        "NaturezaOperacao"  => doc[:natureza],
        "ConsumidorFinal"   => doc.fetch(:consumidor_final, false),
        "IndicadorPresenca" => doc[:indicador_presenca] || 1,
        "IdentificadorInterno" => doc[:identificador_interno],
        "NFReferencia"      => Array(doc[:nf_referencia]).presence,
        # Serie/Numero: só enviados se o builder fornecer; senão o Brasil NFe
        # controla automaticamente (recomendado em producao).
        "Serie"             => doc[:serie],
        "Numero"            => doc[:numero],
        "Cliente"           => doc[:cliente],
        "Produtos"          => doc[:produtos],
        "Pagamentos"        => doc[:pagamentos],
        "EnviarEmail"       => doc.fetch(:enviar_email, false)
      }.compact
    end

    def post(path, body)
      uri = URI("#{BASE_URL}#{path}")
      raise ConfiguracaoInvalida, "Token do Brasil NFe ausente" if token.blank?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 60

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Token"] = token
      req.body = body.to_json

      res = http.request(req)
      parsed = JSON.parse(res.body) rescue { "Error" => "Resposta não-JSON (HTTP #{res.code})", "_raw" => res.body }
      parsed.merge("_http_status" => res.code.to_i)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      { "Error" => "Timeout ao contatar Brasil NFe: #{e.message}", "_http_status" => 0 }
    rescue => e
      { "Error" => "Falha na requisição: #{e.message}", "_http_status" => 0 }
    end

    # Converte a resposta do Brasil NFe no FiscalResult neutro.
    def to_result(resposta)
      ret = resposta["ReturnNF"] || {}
      erro = resposta["Error"].to_s
      status_sefaz = ret["CodStatusRespostaSefaz"]

      status =
        if ret["Ok"] == true || [100, 150].include?(status_sefaz)
          :autorizado
        elsif erro.present? || resposta["_http_status"].to_i >= 400
          :erro
        else
          :rejeitado
        end

      FiscalResult.new(
        status:    status,
        chave:     ret["ChaveNF"],
        protocolo: ret["NumeroProtocolo"],
        numero:    ret["Numero"],
        serie:     ret["Serie"],
        xml:       resposta["Base64Xml"],
        danfe_url: nil, # DANFE vem em Base64File, não URL
        mensagem:  ret["DsStatusRespostaSefaz"].presence || erro.presence,
        bruto:     resposta
      )
    end

    # Converte a resposta de um cancelamento no FiscalResult neutro.
    # SEFAZ: 101 = cancelamento homologado, 135 = evento registrado e vinculado,
    # 155 = cancelamento homologado fora do prazo. Qualquer um = cancelado.
    def to_cancel_result(resposta)
      ret = resposta["ReturnNF"] || resposta["ReturnEvento"] || {}
      erro = resposta["Error"].to_s
      status_sefaz = ret["CodStatusRespostaSefaz"]
      ok_cancel = [101, 135, 155].include?(status_sefaz) || ret["Ok"] == true

      status =
        if ok_cancel
          :cancelado
        elsif erro.present? || resposta["_http_status"].to_i >= 400
          :erro
        else
          :rejeitado
        end

      FiscalResult.new(
        status:    status,
        chave:     ret["ChaveNF"],
        protocolo: ret["NumeroProtocolo"],
        xml:       resposta["Base64Xml"],
        mensagem:  ret["DsStatusRespostaSefaz"].presence || erro.presence,
        bruto:     resposta
      )
    end

    def nao_implementado(op)
      raise NotImplementedError,
            "#{op} do BrasilNfeAdapter ainda não implementado (mapear seção Eventos da doc)."
    end
  end
end
