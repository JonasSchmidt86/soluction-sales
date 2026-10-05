# Brasil NFe API 2.0 — Consultas

Base: `https://api.brasilnfe.com.br/services/fiscal`
Header: `Token` (empresa) obrigatório. `Content-Type: application/json`.

> Transcrição dos pontos técnicos do PDF "Consultas - Brasil NFe - API 2.0".

## PreVisualizarNotaFiscal
`POST /PreVisualizarNotaFiscal` — gera PDF/XML SEM transmitir à SEFAZ e sem
consumir numeração.
- `TipoArquivo`: 0 XML · 1 PDF (default 0) · 2 PDF em Base64File + XML em Base64Xml.
- `TipoEnvio`: 0 = Base64Xml (XML pronto) · 1 = objeto `notaFiscal` (com nFInfos[]).
- `mostrarTarjaPreVisualizacao` (default true) = tarja "SEM VALOR FISCAL".
- Campos por tipo de doc: `notaFiscal` (55/65 → DANFE/DANFCE), `cte`, `mdfe`, `dce`, `nfse`.
- Resposta: `Status` (bool), `Base64File` (PDF ou, p/ NFC-e, HTML), `Base64Xml`
  (só com TipoArquivo=2), `Error`, `Avisos[]`.
- OBS nossa: NFC-e (65) devolve o DANFCE em HTML, não PDF — tratado no FiscalPreview.

## ObterNotasFiscais  (listagem por período)
`POST /ObterNotasFiscais`. Body:
- `TipoDocumentoFiscal` (req): 0 entradas · 1 saídas.
- `DtInicio`/`DtFim` (req, date-time). `TipoAmbiente` 1/2.
- `IdentificadorInterno` (opcional, só saídas). `TipoParticipacao` (entradas): 0 dest / 1 transp / 2 ambos.
- Resposta: `Notas[]` (Chave, IdentificadorInterno, CodLote, Serie, Numero, ModeloDocumento, Valor...), `Error`, `Avisos[]`.

## ConsultarLoteNFe
`POST /ConsultarLoteNFe` body `{ "CodLote": "L-..." }` — status de lote enviado via
/EnviarNotaFiscalLote. Retorna StatusLote (1..5), QtdTotal/Emitida/Erro, Notas[].

## ConsultarNotaFiscal  (situação de um doc já enviado)
`POST /ConsultarNotaFiscal`. Localiza por UM de: `Chave` (44) | `IdentificadorInterno`
| `Numero` (+ `ModeloDocumento`, e `Serie` se houver). Filtros opcionais TipoAmbiente/
ModeloDocumento (0=qualquer).
- Resposta: `Encontrada` (bool), `Nota` (modelo, chave, numero/serie, protocolo, Status:
  autorizada/cancelada/rejeitada/denegada/processando, cod/desc SEFAZ, valor, dest),
  `Historico[]` (tentativas c/ mesmo IdentificadorInterno), `erros[]`, `avisos[]`.
- `RetornarArquivos=true` → Base64Xml + Base64File (PDF, ou HTML p/ NFC-e) se autorizada.
- Uso: confirmar emissão cuja resposta se perdeu; evitar duplicidade por IdentificadorInterno.

## ObterArquivoNotaFiscal  (baixar XML/PDF)
`POST /ObterArquivoNotaFiscal`. Body:
- `ChaveNF` (uma) OU `Chaves[]` (várias, só p/ PDF consolidado).
- `FileType`: 1 XML · 2 PDF. `TipoDocumentoFiscal`: 0 entrada · 1 saída.
- `Base64Logo` opcional. **Resposta = STRING Base64 PURA** (não JSON); erro pode vir JSON.

## ObterArquivoEvento
`POST /ObterArquivoEvento` body `ChaveNF` + `NuProtocolo` + `TipoArquivo`
(1 XML do evento · 2 PDF da CC-e). Resposta = Base64 pura.

## ObterArquivosPorPeriodo  (download em lote .zip/xlsx)
`POST /ObterArquivosPorPeriodo`. Body: DtInicio/DtFim (date), `Type` 0 PDF/1 XML/2 EXCEL,
TipoAmbiente 1/2, `TipoNota` 1 saídas/2 entradas/3 ambos, Chaves[], cpfCnpjs[],
JuntarArquivosPDF, incluirCCe, Situacoes[] (1 autorizada,2 cancelada,3 denegada).
Resposta: `Quantidade`, `Base64FilesCompacted` (zip/xlsx em base64), Error, Avisos[].

## ConsultarCadastroSefaz  (CCC — situação cadastral)
`POST /ConsultarCadastroSefaz` body `{ "uf": "PR", "cpfCnpjIe": "..." }`.
Resposta: status(1/0), cpfCnpj, ie/ieAtual/ieUnica, situacao (1 habilitado,2 suspenso,
3 baixado,4 nulo,5 outros), razaoSocial, regimeApuracao, indicadorCredenciamentoNFe,
fonte (sefaz/receita/indisponivel), Endereco, Contato. Endereço vem CamelCase.

## ConsultarStatusSefaz
`POST /ConsultarStatusSefaz` body `{ "ModeloDocumento": 55 }` (55/58/57/65/67).
Consulta SEMPRE em produção. Resposta: CodStatusRespostaSefaz (107 = "Serviço em
Operação"), DsStatusRespostaSefaz, DsEstadoEmitente, Avisos[], erros[], status(0=ok).
