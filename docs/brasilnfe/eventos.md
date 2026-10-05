# Brasil NFe API 2.0 — Eventos NF-e / NFC-e

Base: `https://api.brasilnfe.com.br/services/fiscal`
Header: `Token` (empresa). `Content-Type: application/json`.
Resposta padrão dos eventos (vem na RAIZ, NÃO em ReturnNF): `DsMotivo`, `DsEvento`,
`DsAmbiente`, `NuProtocolo`, `CodStatusRespostaSefaz`, `NumeroSequencial`, `Status`
(1 processado / 2 aguardando / 3 erro), `Base64Xml`, `Base64File`, `Error`, `Avisos[]`.
Sucesso = Status==1 e CodStatusRespostaSefaz ∈ {100,101,135,150,155}.

> Transcrição dos pontos técnicos do PDF "Eventos NF-e / NFC-e".

## EnviarCartaCorrecao (CC-e)
`POST /EnviarCartaCorrecao`. Body: `TipoAmbiente` (req), `ChaveNF` (44, req),
`Correcao` (15–1000, req), `NumeroSequencial` (opcional, auto), `Correcoes[]` (só CT-e).
- NÃO corrige: valores fiscais (base/alíquota/preço/qtd), remetente/destinatário,
  data emissão/saída, série/número. Nesses casos use NF de devolução.

## CancelarNotaFiscal
`POST /CancelarNotaFiscal`. Body: `ChaveNF` (44, req), `Justificativa` (15–1000, req),
`NumeroProtocolo` (obrigatório só se a nota foi emitida por OUTRO sistema),
`NumeroSequencial` (auto), `DataEvento`, `CpfCnpjRemetenteDCe` (só DC-e).
- Prazo: NF-e 24h, NFC-e 30min após autorização. Passou o prazo → NF de devolução.

## ManifestarNotaFiscal (Manifestação do Destinatário)
`POST /ManifestarNotaFiscal`. Body: `TipoAmbiente` (req), `TipoManifestacao` (req):
1 Confirmação · 2 Ciência · 3 Desconhecimento · 4 Operação não Realizada;
`Chave` (44), `Justificativa` (15–255, obrigatória só p/ tipo 4), `NumeroSequencial`.

## InutilizarNumeracao  (descarta faixa de números NUNCA usada)
`POST /InutilizarNumeracao`. Body: `Justificativa` (15–1000, req), `TipoAmbiente`,
`ModeloDocumento` (55/65/57), `Serie`, `NumeracaoInicial`, `NumeracaoFinal`.
- Só para números NUNCA emitidos (não autorizados/cancelados/denegados).
- Prazo: até o dia 10 do mês seguinte à quebra. NÃO substitui cancelamento.
- OBS nossa: é o oposto de AtualizarNumeracao. Para PULAR números já inutilizados
  em homologação, use AtualizarNumeracao (empresas.md) com Numero acima da faixa.

## EnviarEconf (Conciliação Financeira — NT 2024.002/2025.002)
`POST /EnviarEconf`. Vincula pagamentos a NF-e/NFC-e autorizada (tpEvento 110750).
Body: Chave (44), TipoAmbiente, NumeroSequencial(1–20), DataEvento, Pagamentos[]
(1–100). Cancelar=true + NumeroProtocoloEconf = cancela (tpEvento 110751).

## EnviarEvento (Eventos da Reforma Tributária — NT 2025.002)
`POST /EnviarEvento`. Genérico; `TipoEvento` decide o evento. Body: TipoAmbiente,
Chave (44), TipoEvento, NumeroSequencial(1–20), DataEvento, e campos conforme o tipo
(IndicadorQuitacao, IndicadorAceitacao, DataPrevisaoEntrega, Itens[], etc.).
TipoEvento 110001 = cancelar evento (usa TipoEventoCancelado + ProtocoloEvento).
Principais: 112110 pagamento integral · 112150 previsão de entrega · 211110 crédito
presumido · 211128 aceite débito · 212110/212120 transferência crédito sucessão.
(Para quando formos implementar a Reforma Tributária.)
