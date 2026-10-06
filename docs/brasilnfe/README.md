# Documentação Brasil NFe (API 2.0)

Documentação oficial do provedor **Brasil NFe** (API 2.0), salva para consulta
offline durante o desenvolvimento do módulo fiscal. A doc online é renderizada
por JavaScript e não é acessível por fetch simples — por isso guardamos os PDFs
aqui.

> Coloque os PDFs exportados da doc nesta pasta (`docs/brasilnfe/*.pdf`).
> Este README resume os fatos-chave extraídos para referência rápida; para
> detalhes completos consulte o PDF correspondente.

Base URL: `https://api.brasilnfe.com.br/services/fiscal`
Auth: header `Token: <token da empresa>` (obrigatório em todas as operações fiscais).

## Arquivos nesta pasta

PDFs originais (referência humana) + transcrição em Markdown (consulta do agente —
o agente NÃO lê PDF binário, só os `.md`):

| Tema | PDF | Markdown (ler este) |
|------|-----|---------------------|
| Emissão NF-e/NFC-e | `NF-e e NFC-e - ...pdf` | **`nf-e-nfce.md`** |
| Consultas/preview/arquivos | `Consultas - ...pdf` | **`consultas.md`** |
| Eventos (cancel/CC-e/inutilização/manifestação/reforma) | `Eventos NF-e _ NFC-e - ...pdf` | **`eventos.md`** |
| Empresas/certificado/**numeração** | `Empresas - ...pdf` | **`empresas.md`** |

Ao precisar de detalhes de um endpoint, LEIA o `.md` correspondente.

## EnviarNotaFiscal — fatos-chave (NF-e 55 / NFC-e 65)

### Numeração (Serie / Numero / Lote / Codigo)
- Se enviados em BRANCO, o Brasil NFe controla automaticamente (próximo número
  por **empresa + modelo + série + ambiente**). Hoje o nosso adapter NÃO envia
  esses campos → numeração automática.
- Envie valores **apenas** para controle manual (migração de sistema, múltiplas
  séries, ou PULAR número inutilizado). `Serie` int32, `Numero` int64,
  `Lote` int64, `Codigo` string (código numérico da chave).

### ModeloDocumento (55 / 65) e restrição de CFOP da NFC-e
- 55 = NF-e, 65 = NFC-e.
- **NFC-e (65) aceita SÓ estes CFOPs** (saída a consumidor final):
  **5101, 5102, 5103, 5104, 5115, 5405, 5656, 5667, 5933, 6108, 6109, 6110**.
  Qualquer outro CFOP é rejeitado.
  - Rejeição **725** — CFOP inválido para NFC-e.
  - Rejeição **386** — CFOP incompatível com CSOSN em NFC-e.
- Consequência prática: a tela de NFC-e deve bloquear/avisar CFOP fora dessa
  lista ANTES de enviar (ver fiscal: validação por modelo).

### Finalidade
1 Normal · 2 Complementar · 3 Ajuste · 4 Devolução · 5 Nota de crédito ·
6 Nota de débito. (TpNFDebito obrigatório p/ Finalidade 6; TpNFCredito p/ 5.)

### TipoAmbiente
"1" Produção (validade fiscal real) · "2" Homologação (SEFAZ descarta, sem efeito).
CSC é por ambiente: homologação e produção usam CSC diferentes.

### IndicadorPresenca
0 Não se aplica · 1 Presencial · 2 Internet · 3 Teleatendimento ·
4 NFC-e entrega a domicílio · 5 Presencial fora do estab. · 9 Outros.
- Rejeição **787** — NFC-e com IndicadorPresenca=4 exige destinatário (CPF/CNPJ + endereço).

### TipoDanfe (tpImp)
Não informado = padrão (1 NF-e, 4 NFC-e). 0 sem DANFE · 1 Retrato · 2 Paisagem ·
3 Simplificado · 4 DANFE NFC-e (só 65) · 5 NFC-e em mensagem (só 65) ·
6 Simplificado Tipo 2 (só 55, bobina c/ QR Code).
- OBS: a pré-visualização da NFC-e vem em HTML (não PDF) — tratado no FiscalPreview.

### Resposta (200)
- `Base64Xml`, `Base64File` (PDF/DANFE), `ReturnNF { Numero, Serie, ChaveNF,
  NumeroProtocolo, CodTipoAmbiente, DsTipoAmbiente, CodStatusRespostaSefaz, ... }`,
  `Error` (vazio em sucesso), `Avisos[]`.
- Sucesso SEFAZ: CodStatusRespostaSefaz 100 (autorizado) ou 150.

### Lote assíncrono
- `/EnviarNotaFiscalLote` aceita `nFInfos[]`; resultado real via webhook
  `nfe.lote.finalizado` (ou consulta `/ConsultarLoteNFe` pelo CodLote). Não usado ainda.

### CSC (observação importante)
- O PDF de EnviarNotaFiscal NÃO lista campo de CSC no corpo da requisição — o CSC
  é gerenciado no PAINEL/empresa do provedor (idCSC + token, por ambiente), não
  enviado por requisição. Erro "Código Identificador do CSC no QR-Code não
  cadastrado na SEFAZ" => conferir o CSC da empresa no painel + SEFAZ.
