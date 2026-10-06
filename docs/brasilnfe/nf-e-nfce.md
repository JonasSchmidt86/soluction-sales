# Brasil NFe API 2.0 — NF-e e NFC-e (emissão)

Base: `https://api.brasilnfe.com.br/services/fiscal`
Header: `Token` (empresa). `Content-Type: application/json`.

> Transcrição dos pontos técnicos do PDF "NF-e e NFC-e - Brasil NFe - API 2.0".

## EnviarNotaFiscal
`POST /EnviarNotaFiscal` — transmite NF-e (55) ou NFC-e (65) à SEFAZ. Síncrono
(resposta já traz protocolo, XML base64 e DANFE). NÃO dispara webhook.

### Numeração (Serie / Numero / Lote / Codigo)
- Em BRANCO → Brasil NFe controla automático (próximo por empresa+modelo+série+ambiente).
- Enviar valores só p/ controle manual (migração, múltiplas séries, pular inutilizado).
- `Serie` int32, `Numero` int64, `Lote` int64, `Codigo` string (cNF da chave).

### ModeloDocumento + restrição de CFOP da NFC-e  ⚠
- 55 NF-e · 65 NFC-e.
- **NFC-e (65) aceita SÓ CFOPs: 5101, 5102, 5103, 5104, 5115, 5405, 5656, 5667,
  5933, 6108, 6109, 6110.** Outros = rejeição **725** (CFOP inválido) / **386** (CFOP x CSOSN).

### Finalidade
1 Normal · 2 Complementar · 3 Ajuste · 4 Devolução · 5 Nota de crédito · 6 Nota de débito.
(TpNFDebito obrigatório p/ Finalidade 6; TpNFCredito p/ 5.)

### Campos principais do corpo
TipoAmbiente ("1"/"2"), NaturezaOperacao, ConsumidorFinal (bool), IndicadorPresenca
(0..9; 4 = NFC-e entrega domicílio exige destinatário → rejeição 787), CalcularIBPT,
Observacao/ObservacaoFisco, IdentificadorInterno, NFReferencia[], Cliente{}, Produtos[],
Pagamentos[], Cobranca{}, Transporte{}, Entrega{}, Exporta{}, Retencoes{}, EnviarEmail,
ValorFrete/ValorDesconto/ValorTotal (totais p/ rateio/validação). TipoDanfe: 1 NF-e retrato,
4 DANFCE (só 65), etc.

### Resposta (200)
`Base64Xml`, `Base64File` (PDF/DANFE), `ReturnNF { Numero, Serie, ChaveNF,
NumeroProtocolo, CodTipoAmbiente, DsTipoAmbiente, CodStatusRespostaSefaz, Ok, ... }`,
`Error`, `Avisos[]`. Autorizado = CodStatusRespostaSefaz 100 (ou 150).

### Rejeições citadas
- 725 CFOP inválido para NFC-e · 386 CFOP incompatível com CSOSN em NFC-e.
- 787 NFC-e IndicadorPresenca=4 exige destinatário.
- 206 número já inutilizado · 210/209 IE do destinatário inválida (visto na prática).

### CSC (QR-Code da NFC-e)
O corpo de EnviarNotaFiscal NÃO tem campo de CSC — o CSC (idCSC + token, por ambiente)
é do PAINEL/empresa do provedor. Erro "idCSC do QR-Code não cadastrado na SEFAZ" =
conferir o CSC de homologação/produção no painel + SEFAZ.

## EnviarNotaFiscalLote
`POST /EnviarNotaFiscalLote` — lista `nFInfos[]` (mesmo schema de EnviarNotaFiscal).
Resposta = aceite do lote (CodLote); resultado real via webhook `nfe.lote.finalizado`
ou polling `/ConsultarLoteNFe`. Não usado ainda.
