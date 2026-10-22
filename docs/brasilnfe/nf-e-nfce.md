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

### Cliente / Destinatário (objeto `Cliente`)
- `CpfCnpj` (string): CPF ou CNPJ. Rejeições 208 (CNPJ inválido) / 237 (CPF inválido).
- `NmCliente` (string): nome ou razão social.
- `IndicadorIe` (int, indIEDest): indicador da IE do destinatário. **Default 9.**
  - `1` Contribuinte ICMS → `Ie` obrigatória e válida.
  - `2` Contribuinte isento de inscrição → `Ie` não enviada.
  - `9` Não contribuinte → `Ie` não enviada; aciona DIFAL (EC 87/2015).
- `Ie` (string): inscrição estadual (obrigatória quando `IndicadorIe = 1`).
- `IsUf` (string): inscrição SUFRAMA.
- `Endereco` (object): Cep, Logradouro, Complemento, Numero, Bairro,
  CodMunicipio, Municipio, Uf.
- `Contato` (object): dados de contato.

> **Atenção (rejeição 696):** não enviar `IndicadorIe` faz a API assumir o
> default **9 (não contribuinte)**, e a SEFAZ exige então que a operação seja
> com consumidor final. Em venda/devolução a destinatário contribuinte (com IE),
> enviar `IndicadorIe = 1` + `Ie`. O builder (`montar_cliente`) resolve isso:
> cliente com `rg_ie` válido → `IndicadorIe 1` + `Ie`; sem IE → `9`.

### Transporte (objeto `Transporte`)
Informações sobre transporte e frete. **Default automático:** se `Transporte`
não for enviado, a API assume `ModalidadeFrete = 9` (sem frete). Para frete
efetivo, enviar o bloco com `ModalidadeFrete` 0–4 + dados da transportadora.

- `ModalidadeFrete` (int32): 0 CIF (remetente) · 1 FOB (destinatário) · 2 terceiros ·
  3 próprio remetente · 4 próprio destinatário · 9 sem ocorrência de transporte.
- `NmTransportador` (string): nome/razão social do transportador.
- `CNPJ` (string): CNPJ do transportador.
- `NmMunicipio` (string): município do transportador.
- `DsEndereco` (string): endereço do transportador.
- `IE` (string): inscrição estadual do transportador.
- `UF` (string): UF do transportador.
- `Vagao` (string): vagão (modal ferroviário, se aplicável).
- `Balsa` (string): balsa (modal aquaviário, se aplicável).
- `Veiculo` (object): veículo de tração — `Placa`, `UF`, `RNTC` (Registro
  Nacional de Transporte de Carga).
- `Reboque` (object[]): reboques/carretas — cada um com `Placa`, `UF`, `RNTC`.
- `Volumes` (object[]): volumes transportados — cada um com:
  - `Numero` (string): número do volume.
  - `QuantidadeVolume` (int32): quantidade de volumes.
  - `Especie` (string): espécie da carga (ex.: CAIXAS).
  - `Marca` (string): marca da carga.
  - `PesoBruto` (double) / `PesoLiquido` (double): pesos da carga.
  - `Lacres` (string[]): lista de lacres.

> Nomes confirmados na doc Brasil NFe (API 2.0). Atenção: a quantidade de
> volumes é `QuantidadeVolume` (não "Quantidade"), e `Numero` é o número do
> volume (não a numeração/marca).

### Pagamentos (array `Pagamentos`)
Lista de pagamentos efetuados. Campos de cada item:

- `FormaPagamento` (string, tPag): `01` Dinheiro · `02` Cheque · `03` Cartão de
  Crédito · `04` Cartão de Débito · `05` Cartão da Loja/Crediário · `10` Vale
  Alimentação · `11` Vale Refeição · `12` Vale Presente · `13` Vale Combustível ·
  `14` Duplicata Mercantil · `15` Boleto · `16` Depósito · `17` PIX dinâmico ·
  `18` Transferência/Carteira Digital · `19` Fidelidade/cashback · `20` PIX
  estático · `21` Crédito em Loja · `22` Pgto eletrônico não informado (falha
  hardware) · `23` PIX automático · `24` TEF Book Transfer · `90` Sem pagamento ·
  `91` Pagamento posterior · `99` Outros.
- `IndicadorPagamento` (int32): `0` à vista · `1` a prazo.
- `VlPago` (double): valor pago.
- `VlTroco` (double): valor do troco.
- `Desconto` (double): desconto no pagamento.
- `Descricao` (string, xPag): descrição do meio de pagamento. **Só vai ao XML
  quando `FormaPagamento` = 99 (Outros)**; se omitida nesse caso, sai "Outros".
  Nas demais formas é ignorada. (Nome do campo é `Descricao`, não
  "DescricaoPagamento".)
- Opcionais (NT 2023.004): `DataPagamento`, `CNPJPagamento`+`UFPagamento` (os
  dois ou nenhum), `TipoIntegracao` (bool, TEF), `CNPJCredenciadora`,
  `BandeiraOperadora` (01 Visa…06 Elo…99 Outros), `NumeroAutorizacao`,
  `CNPJRecebedor`, `IdTerminalPagamento`.

### Cobrança (objeto `Cobranca`)
Fatura e parcelas (duplicatas):

- `Fatura`: `Numero`, `Valor` (bruto), `Desconto`, `ValorLiquido`.
- `Parcelas` (array): cada uma com `Vencimento` (date-time) e `Valor`.

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
