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

    # Pre-visualizacao: gera o DANFE/DANFCE (PDF) ou XML do documento SEM
    # transmitir a SEFAZ e sem consumir numeracao. Doc 2.0:
    # POST /PreVisualizarNotaFiscal com TipoEnvio=1 (objeto), onde a(s) nota(s)
    # vao em notaFiscal.nFInfos: [ ... ]. Reaproveita o mesmo payload por nota
    # do EnviarNotaFiscal (montar_payload).
    #
    # tipo_arquivo: 1 = PDF (default), 0 = XML.
    # tarja: exibe "SEM VALOR FISCAL - PRE-VISUALIZACAO" (default true).
    def pre_visualizar(documento, tipo_arquivo: 1, tarja: true)
      nota = montar_payload(documento)
      body = {
        "TipoArquivo"                 => tipo_arquivo.to_i,
        "TipoEnvio"                   => 1,
        "mostrarTarjaPreVisualizacao" => tarja ? true : false,
        "notaFiscal" => {
          "TipoAmbiente"    => ambiente,
          "ModeloDocumento" => documento[:modelo] || 55,
          "nFInfos"         => [nota]
        }
      }
      resposta = post("/PreVisualizarNotaFiscal", body)
      to_preview(resposta, tipo_arquivo: tipo_arquivo)
    end

    # Devolução = emissão com Finalidade 4 + chaves das notas de origem.
    def devolver(documento_origem, itens)
      doc = documento_origem.merge(finalidade: 4)
      doc[:produtos] = itens if itens.present?
      emitir(doc)
    end

    # Cancela uma NF-e/NFC-e autorizada. Doc 2.0: POST /CancelarNotaFiscal
    # com ChaveNF + Justificativa (15-1000). NumeroProtocolo so e obrigatorio
    # quando a nota foi emitida por OUTRO sistema (nao e o nosso caso), mas
    # enviamos quando disponivel. Prazo: NF-e 24h, NFC-e 30min apos autorizacao.
    #
    # referencia: chave de acesso (44 digitos) OU hash { chave:, protocolo: }.
    def cancelar(referencia, justificativa)
      chave, protocolo = extrair_chave_protocolo(referencia)
      just = justificativa.to_s.strip
      raise ConfiguracaoInvalida, "Chave de acesso ausente para cancelamento" if chave.blank?
      raise ConfiguracaoInvalida, "Justificativa deve ter ao menos 15 caracteres" if just.length < 15

      payload = {
        "TipoAmbiente"    => ambiente.to_i,
        "ChaveNF"         => chave,
        "Justificativa"   => just,
        "NumeroProtocolo" => protocolo
      }.compact
      resposta = post("/CancelarNotaFiscal", payload)
      to_evento_result(resposta, status_sucesso: :cancelado)
    end

    # Carta de Correcao Eletronica (CC-e). Doc 2.0: POST /EnviarCartaCorrecao
    # com TipoAmbiente + ChaveNF + Correcao (15-1000). Corrige erros formais
    # (NAO valores fiscais, partes, datas, numero/serie).
    def carta_correcao(referencia, texto)
      chave, = extrair_chave_protocolo(referencia)
      corr = texto.to_s.strip
      raise ConfiguracaoInvalida, "Chave de acesso ausente para carta de correcao" if chave.blank?
      raise ConfiguracaoInvalida, "Correcao deve ter ao menos 15 caracteres" if corr.length < 15

      payload = {
        "TipoAmbiente" => ambiente.to_i,
        "ChaveNF"      => chave,
        "Correcao"     => corr
      }
      resposta = post("/EnviarCartaCorrecao", payload)
      to_evento_result(resposta, status_sucesso: :autorizado)
    end

    # Inutiliza uma faixa de numeracao nunca usada. Doc 2.0: POST
    # /InutilizarNumeracao com TipoAmbiente + ModeloDocumento + Serie +
    # NumeracaoInicial/Final + Justificativa (15-1000).
    def inutilizar(serie:, numero_inicial:, numero_final:, justificativa:, modelo: 55)
      just = justificativa.to_s.strip
      raise ConfiguracaoInvalida, "Justificativa deve ter ao menos 15 caracteres" if just.length < 15

      payload = {
        "TipoAmbiente"     => ambiente.to_i,
        "ModeloDocumento"  => modelo.to_i,
        "Serie"            => serie,
        "NumeracaoInicial" => numero_inicial.to_i,
        "NumeracaoFinal"   => numero_final.to_i,
        "Justificativa"    => just
      }
      resposta = post("/InutilizarNumeracao", payload)
      to_evento_result(resposta, status_sucesso: :autorizado)
    end

    def consultar(_referencia)
      nao_implementado(:consultar)
    end

    # Consulta o status operacional da SEFAZ para um modelo de documento.
    # Doc 2.0: POST /ConsultarStatusSefaz com ModeloDocumento (55/65/57/58/67).
    # A consulta e SEMPRE em producao (independente do ambiente da empresa).
    # Retorna FiscalStatus (operante? / mensagem / uf / codigo).
    def consultar_status(modelo: 55)
      resposta = post("/ConsultarStatusSefaz", { "ModeloDocumento" => modelo.to_i })
      to_status(resposta)
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

    # Converte a resposta do ConsultarStatusSefaz no FiscalStatus neutro.
    # SEFAZ: 107 = "Servico em Operacao" (operante). Outros codigos indicam
    # instabilidade/indisponibilidade. erros/status != 0 = falha na consulta.
    def to_status(resposta)
      cod   = resposta["CodStatusRespostaSefaz"]
      falha = resposta["Error"].present? || resposta["_http_status"].to_i >= 400 || resposta["status"].to_i != 0
      erros = Array(resposta["erros"]).map { |e| e["descricao"] }.compact.presence

      FiscalStatus.new(
        operante:  !falha && cod.to_i == 107,
        codigo:    cod,
        mensagem:  resposta["DsStatusRespostaSefaz"].presence || resposta["Error"].presence || Array(erros).join("; ").presence,
        ambiente:  resposta["DsTipoAmbiente"],
        uf:        resposta["DsEstadoEmitente"],
        avisos:    resposta["Avisos"],
        bruto:     resposta
      )
    end

    # Converte a resposta do PreVisualizarNotaFiscal no FiscalPreview neutro.
    # Resposta: { Status, Base64File, Error, Avisos }. Base64File traz o PDF
    # (TipoArquivo=1) ou o XML (TipoArquivo=0).
    def to_preview(resposta, tipo_arquivo:)
      erro = resposta["Error"].to_s
      ok   = resposta["Status"] == true && resposta["Base64File"].present? && resposta["_http_status"].to_i < 400
      b64  = ok ? resposta["Base64File"] : nil

      FiscalPreview.new(
        pdf_base64: tipo_arquivo.to_i == 1 ? b64 : nil,
        xml_base64: tipo_arquivo.to_i == 0 ? b64 : nil,
        erro:       ok ? nil : (erro.presence || "Falha ao gerar a pré-visualização."),
        avisos:     resposta["Avisos"],
        bruto:      resposta
      )
    end

    # Converte a resposta de um EVENTO (cancelamento/CC-e/inutilizacao) no
    # FiscalResult neutro. IMPORTANTE: diferente da emissao, a resposta de
    # evento vem direto na RAIZ (DsMotivo, NuProtocolo, CodStatusRespostaSefaz,
    # Status, Base64Xml/File, Error) — NAO dentro de ReturnNF.
    #
    # Sucesso: Status == 1 (evento processado) E CodStatusRespostaSefaz de
    # homologacao do evento. SEFAZ: 100/150 (autorizado), 135 (evento registrado
    # e vinculado), 101/155 (cancelamento homologado / fora do prazo).
    # status_sucesso: :cancelado para cancelamento, :autorizado para CC-e/inut.
    def to_evento_result(resposta, status_sucesso:)
      erro = resposta["Error"].to_s
      status_sefaz = resposta["CodStatusRespostaSefaz"]
      proc_status  = resposta["Status"] # 1 processado / 2 aguardando / 3 erro
      ok = proc_status.to_i == 1 && [100, 101, 135, 150, 155].include?(status_sefaz)

      status =
        if ok
          status_sucesso
        elsif proc_status.to_i == 2
          :processando
        elsif erro.present? || resposta["_http_status"].to_i >= 400 || proc_status.to_i == 3
          :erro
        else
          :rejeitado
        end

      FiscalResult.new(
        status:    status,
        protocolo: resposta["NuProtocolo"],
        xml:       resposta["Base64Xml"],
        mensagem:  resposta["DsMotivo"].presence || erro.presence,
        bruto:     resposta
      )
    end

    # Aceita a chave (String) ou um Hash { chave:, protocolo: }.
    def extrair_chave_protocolo(ref)
      if ref.is_a?(Hash)
        [ref[:chave] || ref["chave"], ref[:protocolo] || ref["protocolo"]]
      else
        [ref, nil]
      end
    end

    def nao_implementado(op)
      raise NotImplementedError,
            "#{op} do BrasilNfeAdapter ainda não implementado (mapear seção Eventos da doc)."
    end
  end
end
