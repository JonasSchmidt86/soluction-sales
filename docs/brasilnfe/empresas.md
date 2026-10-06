# Brasil NFe API 2.0 — Empresas

Base: `https://api.brasilnfe.com.br/services/empresa`
Headers: `UserToken` (identifica o usuário; obrigatório em TODOS os métodos) +
`Token` (identifica a empresa; obrigatório em todos EXCETO AdicionarEmpresa e
BuscarTodasEmpresas). `Content-Type: application/json`.

> Transcrição dos pontos técnicos do PDF "Empresas - Brasil NFe - API 2.0".

## Endpoints
- `POST /AdicionarEmpresa` — cadastra empresa, retorna `token` da empresa.
- `POST /EditarEmpresa` — edita dados/config.
- `POST /DeletarEmpresa` — exclui (irreversível; não apaga docs já emitidos).
- `POST /BuscarEmpresa` — dados de uma empresa (header Token).
- `POST /BuscarTodasEmpresas` — lista todas (só UserToken).
- `POST /AlterarCertificado` — troca certificado A1 (.pfx/.p12 em Base64 + Senha).
- `POST /VerificarCertificado` — valida/expira certificado (Interno=true verifica o atual).
- `POST /ConsultarNumeracao` — **lista numerações atuais** (ver abaixo).
- `POST /AtualizarNumeracao` — **ajusta o próximo número** de uma série (ver abaixo).
- `POST /GerarLinkAtivacao`, `AtivarAssinatura`, `CancelarAssinatura`,
  `ConsultarServicos`, `ConsultarFaturas`, `ConsultarFatura` — billing.

## CRT (Regime Tributário) e CST x CSOSN  ⚠ IMPORTANTE
Campo `CRT` da empresa:
- **1 Simples Nacional** ou **4 MEI** → usar **CSOSN** (101,102,103,201,202,203,300,400,500,900).
- **2 Simples - Excesso Sublimite** → usar **CST** (Simples nos federais, ICMS pelo normal).
- **3 Regime Normal (Presumido/Real)** → usar **CST** (00,10,20,30,40,41,50,51,60,70,90).
- O validador REJEITA a emissão se o código for incompatível com o CRT da empresa.
- (Nossa empresa é CRT 1 Simples → CSOSN. Para destacar ICMS na devolução usamos
  CSOSN 900, que é válido no Simples — ver nf-e-nfce.md.)

## ConsultarNumeracao  (resolve "número travado/inutilizado")
`POST /ConsultarNumeracao` — headers Token + UserToken, sem body.
Lista o contador interno por **Empresa + Modelo + Série + Ambiente** = o próximo
número que será usado em emissão automática (quando Serie/Numero/Lote omitidos).
Resposta:
```json
{ "status": true,
  "Numeracoes": [ { "TipoAmbiente": 2, "ModeloDocumento": 65, "Serie": "1",
                    "Numero": 1, "Padrao": true } ],
  "Error": "", "Avisos": [] }
```
- Ao criar a empresa, a API inicializa Numero=1 para cada modelo (55,65,10,57,58,6,21,22)
  nos dois ambientes.
- Usar para: auditar numeração, diagnosticar rejeição de número fora de sequência.

## AtualizarNumeracao  (corrige a numeração pelo nosso sistema)
`POST /AtualizarNumeracao` — headers Token + UserToken.
Body:
```json
{ "TipoAmbiente": 2, "ModeloDocumento": 65, "Serie": "1", "Numero": 10, "Padrao": true }
```
- TipoAmbiente 1 prod / 2 homolog. ModeloDocumento ∈ {55,65,10,57,58,6,21,22}.
- `Numero` = próximo número que passa a vigorar (emissões automáticas partem dele).
- `Padrao=true` marca a série como padrão (desmarca as demais do mesmo modelo+ambiente).
- **ATENÇÃO:** nunca definir Numero <= a um número já AUTORIZADO na mesma
  série/modelo/ambiente (gera chave duplicada / rejeição). Para descartar números
  PULADOS use `/InutilizarNumeracao` (ver eventos.md).
- Casos de uso: migração de ERP, abrir nova série, corrigir pós-incidente
  (ex.: pular faixa inutilizada em homologação — nosso caso da NFC-e nº 1..5).

## AlterarCertificado / VerificarCertificado
- Só A1 ICP-Brasil (.pfx/.p12), CN com o CNPJ da empresa. A3 (token/cartão) NÃO.
- AlterarCertificado: body `Senha` + `Base64CertificateFile`. Resposta: Expirado,
  DtExpiracao, status (1 ok / 2 falha).
- VerificarCertificado: `Interno=true` verifica o certificado já cadastrado.
