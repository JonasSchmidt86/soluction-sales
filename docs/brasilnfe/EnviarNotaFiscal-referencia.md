# Brasil NFe API 2.0 — EnviarNotaFiscal (referência completa de campos)

> Transcrição automática (pdftotext) do PDF oficial "NF-e e NFC-e - Brasil NFe - API 2.0",
> seção **EnviarNotaFiscal** (schema de envio). Gerado para referência dos nomes exatos
> dos campos de cada objeto (Cliente, Produtos, Imposto/ICMS/PIS/COFINS/IPI, Transporte,
> Pagamentos, Cobrança, etc.). O resumo curado fica em `nf-e-nfce.md`.

```text

Transmitir NFe / NFCe
POST https://api.brasilnfe.com.br/services/fiscal/EnviarNotaFiscal

Transmite uma NF-e ou NFC-e para o ambiente autorizador da SEFAZ.

Quando usar
Use este endpoint sempre que for necessário emitir uma NF-e ou NFC-e no ambiente de homologação ou produção,
registrando oficialmente a operação na SEFAZ.

Como funciona na API
O endpoint recebe o objeto completo da nota fiscal e processa internamente:

 1. Validação do XML conforme o schema oficial.
 2. Assinatura digital utilizando o certificado da empresa.
 3. Transmissão ao ambiente autorizador da SEFAZ.
 4. Retorno com o protocolo de autorização e detalhes da resposta oficial.

Nota: Certifique-se de que todos os dados obrigatórios estejam corretamente preenchidos e que o certificado digital
esteja válido para evitar rejeições. Os possíveis resultados da transmissão (autorizado, rejeitado, denegado) estão
descritos na visão geral da seção.

  Esta rota não dispara webhook. Para emissão em lote com notificação assíncrona via webhook, use
   /EnviarNotaFiscalLote . Veja também Webhooks.

Headers

  Token string · required

  Token de identificação da empresa. Obrigatório em todas as operações fiscais (NF-e, NFC-e,
  NFS-e, CT-e, MDF-e, DC-e, Consultas, Escriturações, Energia e Comunicação) e nos métodos
  da seção Empresas que atuam sobre uma empresa específica (Buscar, Editar, Alterar
  Certificado, Verificar Certificado, Gerar Link de Ativação, Deletar, Consultar Numeração,
  Atualizar Numeração). Não é exigido em Adicionar nem em Buscar Todas.

Request Body

  Estrutura principal para emissão ou referência de uma Nota Fiscal.

  Serie integer · int32

  Série da Nota Fiscal.

  Informe este campo somente se utilizar mais de uma série ou se desejar controlar o valor
  manualmente. Se deixado em branco, o Brasil NFe fará o controle automático conforme
  configurado no painel.

  Controle automático
  Se deixados em branco, Serie , Numero e Lote são gerenciados automaticamente pela
  Brasil NFe (próximo número disponível por empresa + modelo + série + ambiente). Envie
  valores apenas se precisar controlar manualmente (ex: migração de sistema, múltiplas séries).

  Ver também
      Numeração e Séries
  Example: 1

  Numero integer · int64

  Número da nota fiscal.
Preencha este campo apenas se desejar controlar o valor manualmente. Se estiver vazio,
o Brasil NFe assumirá o controle automático conforme configurado no painel.

Controle automático
Se deixados em branco, Serie , Numero e Lote são gerenciados automaticamente pela
Brasil NFe (próximo número disponível por empresa + modelo + série + ambiente). Envie
valores apenas se precisar controlar manualmente (ex: migração de sistema, múltiplas séries).

Ver também
    Numeração e Séries
Example: 123456

Lote integer · int64

Lote da Nota Fiscal.

Preencha este campo apenas se desejar controlar o valor manualmente. Se estiver vazio,
o Brasil NFe assumirá o controle automático conforme configurado no painel.

Controle automático
Se deixados em branco, Serie , Numero e Lote são gerenciados automaticamente pela
Brasil NFe (próximo número disponível por empresa + modelo + série + ambiente). Envie
valores apenas se precisar controlar manualmente (ex: migração de sistema, múltiplas séries).

Ver também
    Numeração e Séries
Example: 20250101

Codigo string

Código numérico que compõe a Chave de Acesso. Número gerado pelo emitente para cada
NF-e.

Preencha este campo apenas se desejar controlar o valor manualmente. Se estiver vazio,
o Brasil NFe assumirá a geração do código
Example: 12345678

DataEntradaSaida string · date-time

Data e Hora da saída ou de entrada do produto/serviço.

Default automático
Se não enviada, a API usa a data/hora atual do servidor (timezone -03:00 Brasília). Envie
apenas para backdating autorizado (ajuste, complementar) - a SEFAZ aceita até 30 dias antes
da transmissão.
Example: 2025-06-01T10:00:00-03:00

DataEmissao string · date-time
Data e Hora da saída ou de entrada do produto/serviço (Envia a data atual caso não
informada).

Default automático
Se não enviada, a API usa a data/hora atual do servidor (timezone -03:00 Brasília). Envie
apenas para backdating autorizado (ajuste, complementar) - a SEFAZ aceita até 30 dias antes
da transmissão.
Example: 2025-06-01T10:00:00-03:00

Justificativa string

Utilizar quando o tipo de emissão for diferente de normal.

Acionamento automático
A Brasil NFe comuta automaticamente para contingência quando a SEFAZ fica offline por mais
que o limite configurado na empresa. Os modos são:

    1 - Normal (online).
    3 - SCAN (contingência via Sistema de Contingência do Ambiente Nacional).
    4 - EPEC (Evento Prévio de Emissão em Contingência) - SEFAZ autoriza depois.
    5 - FS-Offline (Formulário de Segurança offline).

Justificativa    é obrigatória quando TipoEmissao ≠ 1 .

Ver também
    Contingência
Example: Emissão em contingência devido a problemas técnicos.

NFReferencia string[]

Lista de Chaves de Acesso de Notas Fiscais de Referência.

NFPagamentoAntecipado string[] · maxItems: 99

Grupo de notas de antecipação de pagamento (gPagAntecipado - Reforma Tributária). Chaves
de acesso (44 dígitos) das NF-e de antecipação de pagamento (nota de débito, Finalidade 6) a
abater na nota de fornecimento do bem/serviço. Máximo de 99 chaves. Somente modelo 55.

IndicadorPresenca integer · int32

Indicador de presença do comprador no estabelecimento comercial no momento da operação.

Rejeição SEFAZ
    787 - NFC-e com IndicadorPresenca=4 (entrega a domicílio) exige identificação do
    destinatário (Cliente com CPF/CNPJ e endereço).

Ver também
    Rejeições SEFAZ

Valores Possíveis:
0 : Não se aplica

1 : Operação presencial

2 : Operação não presencial, pela Internet

3 : Operação não presencial, Teleatendimento

4 : NFC-e com entrega a domicílio

5 : Presencial fora do estabelecimento

9 : Operação não presencial, outros

Example: 1

Intermediador object

Dados do intermediador/marketplace (site ou plataforma de terceiros). Omitir em operação
sem intermediador (indIntermed = 0). Preencher em operação em site/plataforma de terceiros
(indIntermed = 1). Só é válido quando IndicadorPresenca for 2, 3, 4 ou 9.

   Dados do intermediador/marketplace (site ou plataforma de terceiros). Omitir em operação sem intermediador
   (indIntermed = 0). Preencher em operação em site/plataforma de terceiros (indIntermed = 1). Só é válido quando
   IndicadorPresenca for 2, 3, 4 ou 9.

   Cnpj string

   CNPJ do intermediador da transação (marketplace/plataforma de terceiros). Obrigatório.

   IdCadIntTran string

   Identificação do vendedor no site do intermediador (usuário/login cadastrado). Obrigatório.

ConsumidorFinal boolean

Indica operação com Consumidor final.

Valores Possíveis:

falso : Normal

verdadeiro : Consumidor final

Example: true

CalcularIBPT boolean

Efetuar cálculo do IBPT automaticamente. Por padrão o cálculo só é aplicado quando
 ConsumidorFinal também for verdadeiro , que é o caso em que a Lei 12.741/2012 obriga a
informação. Para calcular também em operações que não são para consumidor final (ex.:
transferência entre estabelecimentos), ative na empresa a opção "Calcular tributos
aproximados (IBPT) também em notas para não consumidor final", em Configurações >
Serviços > NF-e.

Cálculo automático
Com CalcularIBPT=true , a API consulta a tabela IBPT por NCM e preenche vTotTrib
(tributos federais, estaduais e municipais estimados) em cada item e no total da nota.
Exigência da Lei 12.741/2012.

Valores Possíveis:

falso : Não Calcular

verdadeiro : Calcular

Example: true

NaturezaOperacao string

Descrição da Natureza da Operação.
Example: Venda de Mercadoria Adquirida ou Recebida de Terceiros

ModeloDocumento integer · int32

Código do modelo do Documento Fiscal.

Restrição
NFC-e ( ModeloDocumento=65 ) aceita apenas CFOPs de saída de venda a consumidor final
(5101, 5102, 5103, 5104, 5115, 5405, 5656, 5667, 5933, 6108, 6109, 6110). Outros CFOPs são
rejeitados.

Rejeições SEFAZ
    725 - CFOP inválido para NFC-e.
    386 - CFOP incompatível com CSOSN em NFC-e.

Valores Possíveis:

55 : NF-e

65 : NFC-e

Example: 55

Finalidade integer · int32

Finalidade da emissão da NF-e.

Valores Possíveis:

1 : Normal

2 : Complementar

3 : Ajuste

4 : Devolução

5 : Nota de crédito

6 : Nota de débito

Example: 1
TpNFDebito integer · int32

Tipo de Nota de Débito. Obrigatório quando Finalidade = 6.

Valores Possíveis:

1 : Transferência de créditos para Cooperativas

2 : Anulação de Crédito por Saídas Imunes/Isentas

3 : Débitos de notas fiscais não processadas na apuração

4 : Multa e juros

5 : Transferência de crédito de sucessão

6 : Pagamento antecipado

7 : Perda em estoque

TpNFCredito integer · int32

Tipo de Nota de Crédito. Obrigatório quando Finalidade = 5.

Valores Possíveis:

1 : Multa e juros

2 : Apropriação de crédito presumido de IBS sobre saldo devedor na ZFM

3 : Retorno por recusa total na entrega ou por não localização do destinatário

4 : Redução de valores

5 : Transferência de crédito na sucessão

6 : Retorno por recusa parcial na entrega

TipoDanfe integer | null · int32

Formato de impressão do DANFE (tag tpImp). Não informado = padrão atual (1 para NF-e, 4
para NFC-e).

Valores Possíveis:

0 : Sem geração de DANFE

1 : DANFE normal, Retrato (padrão NF-e)

2 : DANFE normal, Paisagem

3 : DANFE Simplificado

4 : DANFE NFC-e (padrão NFC-e; somente modelo 65)

5 : DANFE NFC-e em mensagem eletrônica (somente modelo 65)

6 : DANFE Simplificado Tipo 2 (NT 2026.002/2026.003, Ajuste SINIEF 13/26; somente
modelo 55) - NF-e de varejo em bobina com QR Code

TipoAmbiente integer
Identificação do Ambiente.

Ambiente de emissão
    1 (Produção) - o documento emitido tem validade fiscal real e é reportado ao
    destinatário.
    2 (Homologação) - ambiente de teste; a SEFAZ descarta o documento após alguns dias,
    sem efeito fiscal.

Use homologação durante o desenvolvimento e a integração; só alterne para produção depois
que o fluxo estiver validado.

Valores Possíveis:

1 : Produção

2 : Homologação

Example: 2

Observacao string

Observação da NF.
Example: Documento emitido conforme a legislação vigente.

ObservacaoFisco string

Observação Fisco da NF.
Example: Informações fiscais complementares.

IdentificadorInterno string

Identificador Interno do sistema emissor.
Example: PEDIDO-12345

Cliente object

Dados do Cliente (Destinatário) da Nota Fiscal.

   Dados do Cliente (Destinatário) da Nota Fiscal.

   CpfCnpj string

   CPF ou CNPJ do cliente.

   Rejeição SEFAZ
       208 - CNPJ do destinatário inválido (dígito verificador incorreto ou CNPJ não cadastrado
       na Receita Federal).

   Valide o DV antes de transmitir. A API valida localmente antes do envio à SEFAZ.

   Ver também
       Rejeições SEFAZ
Rejeição SEFAZ
    237 - CPF do destinatário inválido (DV incorreto).

Ver também
    Rejeições SEFAZ
Example: 39658743000199

NmCliente string

Nome ou Razão Social do cliente.
Example: CLIENTE TESTE LTDA

IndicadorIe integer · int32

Indicador da Inscrição Estadual do destinatário.

DIFAL automático
A API calcula e aplica o Diferencial de Alíquota (DIFAL) automaticamente em operações
interestaduais para consumidor final não contribuinte (EC 87/2015). Não é preciso enviar os
valores de vICMSUFDest , vFCPUFDest e vICMSUFRemet - a API deriva a partir da alíquota
interna da UF origem vs. UF destino.

Quando se aplica
Quando Cliente.IndicadorIe = 9 (não contribuinte), UF destino ≠ UF origem, e o CFOP não
está na lista de exceções (1202, 2202, 2502, 2652, 2653, 5101, 5102, 5103, 5104, 5115, 5406,
5656, 5667, 5933).

Ver também
    DIFAL e EC 87/2015

Obrigatoriedade condicional
     IndicadorIe = 1    (contribuinte ICMS) → IE é obrigatória e deve ser válida.
     IndicadorIe = 2    (contribuinte isento) → IE não enviada.
     IndicadorIe = 9    (não contribuinte) → IE não enviada; aciona regras de DIFAL.

Ver também
    DIFAL

Valores Possíveis:

1 : Contribuinte ICMS

2 : Contribuinte isento de Inscrição

9 : Não Contribuinte

Example: 9
Default: 9
Ie string

Inscrição Estadual do cliente.

Obrigatoriedade condicional
     IndicadorIe = 1    (contribuinte ICMS) → IE é obrigatória e deve ser válida.
     IndicadorIe = 2    (contribuinte isento) → IE não enviada.
     IndicadorIe = 9    (não contribuinte) → IE não enviada; aciona regras de DIFAL.

Ver também
    DIFAL
Example: ISENTO

IsUf string

Inscrição SUFRAMA.
Example: 123456789

Endereco object

Detalhes do Endereço do Cliente.

   Detalhes do Endereço do Cliente.

   Cep string

   CEP do endereço do cliente.
   Example: 30112000

   Logradouro string

   Logradouro do endereço do cliente.
   Example: Rua Exemplo, 123

   Complemento string

   Complemento do endereço do cliente.
   Example: Sala 101

   Numero string

   Número do endereço do cliente.
   Example: 123

   Bairro string

   Bairro do endereço do cliente.
   Example: Centro

   CodMunicipio string

   Código do município (padrão IBGE).
      Example: 3106200

      Municipio string

      Nome do município do cliente.
      Example: Belo Horizonte

      Uf string

      Sigla da Unidade Federativa do cliente.
      Example: MG

      CodPais integer · int32

      Código do país (Padrão: 1058 para Brasil).
      Example: 1058
      Default: 1058

      Pais string

      Nome do país (Padrão: BRASIL).
      Example: BRASIL
      Default: BRASIL

   Contato object

   Informações de Contato (Telefone e Email).

      Informações de Contato (Telefone e Email).

      Telefone string

      Número de telefone.
      Example: 3133334444

      Email string · email

      Endereço de e-mail.
      Example: contato@exemplo.com.br

      Fax string

      Número de fax.
      Example: 3133335555

Produtos object[]

Lista de produtos ou serviços da Nota Fiscal.

   Detalhes de um Produto ou Serviço na Nota Fiscal.

   NmProduto string
Descrição do Produto.
Example: Notebook Dell Latitude

CodProdutoServico string

Código do produto ou serviço.
Example: NBLT001

EAN string

GTIN (Global Trade Item Number) do produto, antigo código EAN ou código de barras.
Example: 7891234567890

NCM string

Código NCM (8 posições). Informar 00 em caso de serviço ou item sem produto (Ex.
transferência de crédito).
Example: 84713012

CEST string

Código CEST (Código Especificador da Substituição Tributária).

Obrigatoriedade condicional
O CEST é obrigatório quando o produto tem CST ∈ {10, 30, 60, 70} ou CSOSN ∈ {201, 202,
203, 500, 900} (operações com ICMS por Substituição Tributária). Envie sempre 7 dígitos.

Rejeições SEFAZ
    806 - Operação com ICMS-ST sem informação do CEST.

Ver também
    ICMS-ST e CEST
Example: 1300800

UnidadeComercial string

Unidade de medida.
Example: UND

UnidadeComercialTributavel string

Unidade de medida tributável.

Usado em operações para exterior seguindo a tabela da SEFAZ
Example: UND

Quantidade number · double

Quantidade Comercial do item.
Example: 1
QuantidadeTributavel number · double

Quantidade tributável da unidade de medida.

Nota: Caso este campo não seja informado, o sistema utilizará por padrão o valor contido no
campo Quantidade .
Example: 1

ValorUnitario number · double

Valor Unitário.
Example: 2500

ValorUnitarioTributavel number · double

Valor unitário de tributação do item.

Nota: Caso este campo não seja informado, o sistema utilizará por padrão o valor contido no
campo ValorUnitario .
Example: 2500

ValorTotal number · double

Valor Total Bruto.
Example: 2500

ValorDesconto number · double

Valor do Desconto.
Example: 50

ValorSeguro number · double

Valor Seguro.
Example: 0

ValorFrete number · double

Valor Frete.
Example: 20

ValorOutrasDespesas number · double

Valor Outras Despesas.
Example: 0

CFOP integer · int32

Código Fiscal de Operações e Prestações.

Derivação automática
Não envie tpNF - a API deriva a partir do CFOP do primeiro produto:

    CFOP 1xxx/2xxx/3xxx → tpNF = 0 (entrada)
    CFOP 5xxx/6xxx/7xxx → tpNF = 1 (saída)
Se houver CFOPs de entrada e saída misturados na mesma nota, o validador rejeita (rejeição
174).

Ver também
    CFOP e derivações

Derivação automática
idDest   é derivado do CFOP e da UF do destinatário vs. UF emitente:

    1 - Operação interna (mesma UF).
    2 - Operação interestadual.
    3 - Operação com exterior (CFOP 7xxx ou 3xxx).

Ver também
    CFOP e derivações

Cuidado
Todos os produtos da nota precisam ter CFOPs do mesmo tipo (todos de entrada
1xxx/2xxx/3xxx ou todos de saída 5xxx/6xxx/7xxx). Misturar dispara rejeição 174 da SEFAZ.

Rejeições SEFAZ
    174 - CFOPs de entrada e saída misturados na mesma NF-e.

Restrição
NFC-e ( ModeloDocumento=65 ) aceita apenas CFOPs de saída de venda a consumidor final
(5101, 5102, 5103, 5104, 5115, 5405, 5656, 5667, 5933, 6108, 6109, 6110). Outros CFOPs são
rejeitados.

Rejeições SEFAZ
    725 - CFOP inválido para NFC-e.
    386 - CFOP incompatível com CSOSN em NFC-e.

Example: 5102

NItemPed integer · int32

Número do item do Pedido de Compra.
Example: 1

xPed string

Número do Pedido de Compra.
Example: PC0001
InformacaoAdicional string

Informações adicional do item.
Example: Garantia estendida de 1 ano.

OrigemProduto integer · int32

Origem da mercadoria.

Valores Possíveis:

0 : Nacional, exceto as indicadas nos códigos 3, 4, 5 e 8

1 : Estrangeira - Importação direta, exceto a indicada no código 6

2 : Estrangeira - Adquirida no mercado interno, exceto a indicada no código 7

3 : Nacional, mercadoria ou bem com Conteúdo de Importação superior a 40% e inferior ou
igual a 70%

 4 : Nacional, cuja produção tenha sido feita em conformidade com os processos produtivos
básicos

5 : Nacional, mercadoria ou bem com Conteúdo de Importação inferior ou igual a 40%

6 : Estrangeira - Importação direta, sem similar nacional, constante em lista da CAMEX e gás
natural

7 : Estrangeira - Adquirida no mercado interno, sem similar nacional, constante lista CAMEX e
gás natural

8 : Nacional, mercadoria ou bem com Conteúdo de Importação superior a 70%

Example: 0

cBenef string

Código de Benefício Fiscal utilizado na NF-e, conforme definido na tabela de cada Unidade
Federativa (UF).
Example: PR123456

CodTributacao string

Código do grupo tributário cadastrado no Painel, para automação de impostos.

Quando informado: o sistema aplica automaticamente CFOP, CST, ICMS, IPI, PIS e COFINS do
grupo - você não precisa preencher o bloco Imposto nem o CFOP do item.
Example: TRIB-PADRAO

Imposto object

Detalhes dos impostos aplicáveis ao produto.

   Detalhes dos impostos aplicáveis ao produto.

   ICMS object

   Detalhes do Imposto sobre Circulação de Mercadorias e Serviços (ICMS).
Detalhes do Imposto sobre Circulação de Mercadorias e Serviços (ICMS).

CodSituacaoTributaria string

Código da Situação Tributária (CST ou CSOSN).

Obrigatoriedade por regime
     CRT 1 (Simples Nacional) ou CRT 4 (MEI) → use CSOSN (101, 102, 103, 201, 202, 203,
     300, 400, 500, 900).
     CRT 2 (Simples Nacional - Excesso Sublimite) → use CST: a empresa continua no
     Simples para os tributos federais, mas recolhe o ICMS pelo regime normal.
     CRT 3 (Regime Normal: Lucro Presumido/Real) → use CST (00, 10, 20, 30, 40, 41, 50, 51,
     60, 70, 90).

O validador rejeita a emissão se o código informado for incompatível com o CRT da empresa.

Ver também
     CSOSN vs CST
     Regimes Tributários (CRT)

Valores Possíveis:

 00 : Tributada integralmente

 10 : Tributada e com cobrança do ICMS por Substituição Tributária (ST)

 20 : Com redução de Base de Cálculo

 30 : Isenta ou não tributada e com cobrança do ICMS por ST

 40 : Isenta

 41 : Não tributada

 50 : Suspensão

 51 : Diferimento

 60 : ICMS cobrado anteriormente por substituição tributária (Substituído)

 70 : Com redução de Base de Cálculo e cobrança do ICMS por ST

 90 : Outras

 101 : Tributada pelo Simples Nacional com permissão de crédito

 102 : Tributada pelo Simples Nacional sem permissão de crédito

 103 : Isenção do ICMS no Simples Nacional para faixa de receita bruta

 201 : Tributada pelo Simples Nacional com permissão de crédito e com cobrança do ICMS por
ST

 202 : Tributada pelo Simples Nacional sem permissão de crédito e com cobrança do ICMS por
ST
203 : Isenção do ICMS no Simples Nacional para faixa de receita bruta e com cobrança do
ICMS por ST

300 : Imune

400 : Não tributada pelo Simples Nacional

500 : ICMS cobrado anteriormente por substituição tributária (Substituído) ou por antecipação

900 : Outros (demais operações)

Example: 102

AliquotaICMS number · double

Alíquota ICMS – Obrigatório para situação tributária nº 101 e 201.

Alíquotas interestaduais
Para saídas com destino a outras UFs, a alíquota padrão é 12% (Sul/Sudeste exceto ES) ou 7%
(Norte/Nordeste/Centro-Oeste e ES). A alíquota interna da UF varia (tipicamente 17%–20%).
Produtos importados com conteúdo > 40% usam 4%.

Ver também
    Alíquotas ICMS por UF
Example: 18

AliquotaICMSST number · double

Alíquota ICMS ST – Obrigatório para situação tributária nº 101 e 201. Informe só a alíquota do
ICMS, sem o FCP: o FCP da substituição tributária vai em AliquotaFCPST .
Example: 0

AliquotaMVA number · double

Margem de Valor Agregado (MVA) – Obrigatório para situação tributária nº 201, 202 e 203.

Cálculo da base ST
A MVA (Margem de Valor Agregado) é usada para calcular a base da Substituição Tributária:
BaseST = (vProd + vFrete + vSeg + vOutro - vDesc) × (1 + MVA%). A MVA varia por UF destino
e NCM - consulte o protocolo/convênio aplicável.

Ver também
    ICMS-ST e CEST
Example: 35

AliquotaCredito number · double

Alíquota aplicável de cálculo de crédito – Obrigatório para situação tributária nº 101 e 201.
Example: 0

RedICMS number · double
Percentual de Redução da Base de Cálculo do ICMS.
Example: 0

RedICMSST number · double

pRedBCST - Percentual de redução da base de cálculo do ICMS ST. Informado (inclusive 0): a
base do ST parte do valor da operação sem a redução própria ( RedICMS ) e aplica só este
percentual. Não informado: a redução própria ( RedICMS ) também reduz a base do ST. Use 0
quando a redução vale só para a operação própria e não deve passar para o ST.
Example: 0

BaseCalculo number | null · double

Base de Cálculo do ICMS. Quando não informado, é utilizado o valor dos produtos.
Example: 1000

ValorIcms number | null · double

Valor do ICMS. Calculado automaticamente quando não informado.
Example: 180

motivoDesoneracaoIcms integer | null · int32

Motivo da desoneração do ICMS.

Valores Possíveis:

1 : Táxi

2 : Deficiente Físico

3 : Produtor Agropecuário

4 : Frotista / Locadora

5 : Diplomático / Consular

6 : Utilitários e Motocicletas da Amazônia Ocidental e Áreas de Livre Comércio

7 : SUFRAMA

8 : Venda a Órgãos Públicos

9 : Outros

10 : Deficiente Condutor

11 : Deficiente não Condutor

16 : Olimpíadas Rio 2016

Example: 3

valorDesoneracaoIcms number | null · double

Valor da desoneração do ICMS.
Example: 100

aliquotaDiferimento number | null · double
Percentual de diferimento do ICMS. Utilizado somente no CST 51.
Example: 33.33

AliquotaFCP number | null · double

pFCP - Percentual do Fundo de Combate à Pobreza (FCP) da operação própria. Aceito nos CST
00, 10, 20, 51, 70 e 90. A API calcula o valor (vFCP = BaseCalculoFCP x AliquotaFCP / 100) e o
total vFCP da nota; o FCP próprio não soma no valor total da nota (vNF). Quando não
informado, a API usa o FCP geral da UF do emitente (RJ 2%, AL 1%, SE 1%) só em NF-e/NFC-e
de saída normal interna, CST 00 ou 10, sem redução de base e com AliquotaICMS igual à
alíquota modal da UF (RJ 20%, AL 20,5%, SE 19%); nos demais casos, sem este campo o FCP
não é destacado. Envie 0 para não destacar o FCP. Em venda interestadual para consumidor
final não contribuinte não informe: o FCP da UF de destino vai no grupo do DIFAL
(vFCPUFDest), calculado automaticamente (rejeição 876).

Variação por UF
O FCP (Fundo de Combate à Pobreza) é um adicional ao ICMS com alíquotas que variam por
UF (normalmente entre 0% e 2%). Alguns estados não aplicam FCP em todas as mercadorias.
Consulte a legislação da UF destino.

Ver também
    FCP e FCP-ST por UF
Example: 2

BaseCalculoFCP number | null · double

vBCFCP - Base de cálculo do FCP da operação própria. Quando não informada, é a base do
ICMS (vBC). No CST 00 o FCP é sempre calculado sobre a base do ICMS (o leiaute não tem
vBCFCP nesse grupo).
Example: 1000

AliquotaFCPST number | null · double

pFCPST - Percentual do FCP retido por substituição tributária. Aceito nos CST 10, 30, 70 e 90
e nos CSOSN 201, 202, 203 e 900. A API calcula o valor como BaseCalculoFCPST x
AliquotaFCPST / 100 - vFCP (regra N23d-10 da SEFAZ: o FCP-ST desconta o FCP próprio do
item) e soma o vFCPST no total da nota (vNF), como o ICMS-ST. Não há preenchimento
automático: por mudar o total da nota, o FCP-ST só é destacado quando este campo é
informado.

Variação por UF
O FCP (Fundo de Combate à Pobreza) é um adicional ao ICMS com alíquotas que variam por
UF (normalmente entre 0% e 2%). Alguns estados não aplicam FCP em todas as mercadorias.
Consulte a legislação da UF destino.

Ver também
    FCP e FCP-ST por UF
Example: 2
BaseCalculoFCPST number | null · double

vBCFCPST - Base de cálculo do FCP-ST. Quando não informada, é a base do ICMS-ST (vBCST).
Example: 1400

modalidadeBcIcms integer · int32

Modalidade de determinação da Base de Cálculo do ICMS.

Valores Possíveis:

0 : Margem Valor Agregado (%)

1 : Pauta (valor)

2 : Preço Tabelado Máximo (valor)

3 : Valor da Operação

Example: 3

STRetido object

Grupo de ICMS-ST retido em operação anterior. Preencher SOMENTE em CST 60 ou CSOSN
500 (revenda de mercadoria cujo ICMS-ST já foi retido por substituição tributária). Quando
informado, prevalece sobre a estimativa automática derivada da configuração de ST do
produto.

   Grupo de ICMS-ST retido em operação anterior. Preencher SOMENTE em CST 60 ou CSOSN 500
   (revenda de mercadoria cujo ICMS-ST já foi retido por substituição tributária). Quando informado,
   prevalece sobre a estimativa automática derivada da configuração de ST do produto.

   BaseCalculo number · double

   vBCSTRet - Base de cálculo do ICMS-ST retido na operação anterior.
   Example: 100

   AliquotaConsumidorFinal number · double

   pST - Alíquota suportada pelo consumidor final (alíquota interna do destino + FCP).
   Example: 18

   ValorICMSSubstituto number · double

   vICMSSubstituto - Valor do ICMS próprio do substituto cobrado na operação anterior.
   Example: 12

   ValorICMSST number · double

   vICMSSTRet - Valor do ICMS-ST retido na operação anterior. Opcional: quando não informado,
   é calculado por (BaseCalculo x AliquotaConsumidorFinal / 100 - ValorICMSSubstituto).
   Informe o valor fiel da nota de entrada quando ele divergir da fórmula padrão.
   Example: 6

   BaseCalculoFCP number · double

   vBCFCPSTRet - Base de cálculo do FCP retido por ST na operação anterior.
      AliquotaFCP number · double

      pFCPSTRet - Alíquota do FCP retido por ST na operação anterior. O valor (vFCPSTRet) é
      calculado automaticamente por BaseCalculoFCP x AliquotaFCP / 100 e somado no total
      vFCPSTRet da nota. Não confundir com ICMS.AliquotaFCPST , que é o FCP da ST gerada na
      própria nota (CST 10, 30, 70, 90).

      Variação por UF
      O FCP (Fundo de Combate à Pobreza) é um adicional ao ICMS com alíquotas que variam por
      UF (normalmente entre 0% e 2%). Alguns estados não aplicam FCP em todas as mercadorias.
      Consulte a legislação da UF destino.

      Ver também
           FCP e FCP-ST por UF

      PercentualReducaoBaseEfetiva number · double

      pRedBCEfet - Percentual de redução da base de cálculo efetiva (consumidor final).

      BaseCalculoEfetiva number · double

      vBCEfet - Base de cálculo efetiva (consumidor final). Opcional: quando não informada, é
      calculada por (ValorTotal + frete + seguro + outras despesas - desconto) x (1 -
      PercentualReducaoBaseEfetiva/100). Informe o valor fiel quando a composição da base
      divergir.

      AliquotaEfetiva number · double

      pICMSEfet - Alíquota do ICMS efetiva (consumidor final). O valor (vICMSEfet) é calculado
      automaticamente por BaseCalculoEfetiva x AliquotaEfetiva / 100.

   AliquotaAdRemRetido number · decimal

   adRemICMSRet - Alíquota ad rem do ICMS retido anteriormente. Obrigatório no CST 61
   (tributação monofásica sobre combustíveis cobrada anteriormente).

   QuantidadeMonoRetido number · decimal

   qBCMonoRet - Quantidade tributada retida anteriormente (em unidade de medida da
   legislação). Opcional no CST 61. Quando não informada, assume a quantidade comercial do
   item.

   ValorIcmsMonoRetido number · decimal

   vICMSMonoRet - Valor do ICMS retido anteriormente no CST 61. Opcional: quando não
   informado, é calculado por QuantidadeMonoRetido x AliquotaAdRemRetido.

IPI object

Detalhes do Imposto sobre Produtos Industrializados (IPI).
   Detalhes do Imposto sobre Produtos Industrializados (IPI).

   CodEnquadramento string

   Código de Enquadramento Legal do IPI.
   Example: 999

   CodSituacaoTributaria string

   Código da Situação Tributária do IPI.

   Valores Possíveis:

    01 : Entrada com Recuperação de Crédito

    02 : Entrada Importada com Recuperação de Crédito

    03 : Entrada Não Tributada

    04 : Entrada Imune

    05 : Entrada com Suspensão

    49 : Outras Entradas

    51 : Saída Tributada com Alíquota Zero

    52 : Saída Não Tributada

    53 : Saída Imune

    54 : Saída com Suspensão

    55 : Saída Isenta

    99 : Outras Saídas

   Example: 53

   Aliquota number · double

   Alíquota do IPI.
   Example: 10

   ValorIpiDevolvido number · double

   Valor do IPI devolvido.
   Example: 0

   PercentualMercadoriaDevolvida number · double

   Percentual da mercadoria devolvida.
   Example: 100

PIS object

Detalhes do Programa de Integração Social (PIS).
Detalhes do Programa de Integração Social (PIS).

CodSituacaoTributaria string

Código da Situação Tributária do PIS.

Valores Possíveis:

 01 : Operação Tributável com Alíquota Básica

 02 : Operação Tributável com Alíquota Diferenciada

 03 : Operação Tributável por Quantidade

 04 : Operação Tributável Monofásica - Revenda a Alíquota Zero

 05 : Operação Tributável por Substituição Tributária

 06 : Operação Tributável a Alíquota Zero

 07 : Operação Isenta da Contribuição

 08 : Operação sem Incidência da Contribuição

 09 : Operação com Suspensão da Contribuição

 49 : Outras Saídas

 50 : Operação com Direito a Crédito - Vinculada Exclusivamente a Receita Tributada no
Mercado Interno

 51 : Operação com Direito a Crédito - Vinculada Exclusivamente a Receita Não Tributada no
Mercado Interno

 52 : Operação com Direito a Crédito - Vinculada a Receitas Tributadas e Não-Tributadas no
Mercado Interno

 53 : Operação com Direito a Crédito - Vinculada Exclusivamente a Receitas de Exportação

 54 : Operação com Direito a Crédito - Vinculada a Receitas Tributadas no Mercado Interno e
de Exportação

 55 : Operação com Direito a Crédito - Vinculada a Receitas Não-Tributadas no Mercado
Interno e de Exportação

 56 : Operação com Direito a Crédito - Vinculada a Receitas Tributadas e Não-Tributadas no
Mercado Interno, e de Exportação

 60 : Crédito Presumido - Operação de Aquisição Vinculada Exclusivamente a Receita
Tributada no Mercado Interno

 61 : Crédito Presumido - Operação de Aquisição Vinculada Exclusivamente a Receita Não
Tributada no Mercado Interno

 62 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Tributadas e Não-
Tributadas no Mercado Interno

 63 : Crédito Presumido - Operação de Aquisição Vinculada Exclusivamente a Receitas de
Exportação
    64 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Tributadas e de
   Exportação

    65 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Não-Tributadas no
   Mercado Interno e de Exportação

    66 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Tributadas e Não-
   Tributadas no Mercado Interno, e de Exportação

    67 : Crédito Presumido - Outras Operações

    70 : Operação de Aquisição sem Direito a Crédito

    71 : Operação de Aquisição com Isenção

    72 : Operação de Aquisição com Suspensão

    73 : Operação de Aquisição a Alíquota Zero

    74 : Operação de Aquisição sem Incidência da Contribuição

    75 : Operação de Aquisição por Substituição Tributária

    98 : Outras Entradas

    99 : Outras Operações

   Example: 07

   Aliquota number · double

   Alíquota do PIS.
   Example: 0.65

   BaseCalculo number | null · double

   Base de Cálculo do PIS. Quando não informado, é utilizado o valor dos produtos.
   Example: 1000

COFINS object

Detalhes da Contribuição para o Financiamento da Seguridade Social (COFINS).

   Detalhes da Contribuição para o Financiamento da Seguridade Social (COFINS).

   CodSituacaoTributaria string

   Código da Situação Tributária do COFINS.

   Valores Possíveis:

    01 : Operação Tributável com Alíquota Básica

    02 : Operação Tributável com Alíquota Diferenciada

    03 : Operação Tributável por Quantidade

    04 : Operação Tributável Monofásica - Revenda a Alíquota Zero
05 : Operação Tributável por Substituição Tributária

06 : Operação Tributável a Alíquota Zero

07 : Operação Isenta da Contribuição

08 : Operação sem Incidência da Contribuição

09 : Operação com Suspensão da Contribuição

49 : Outras Saídas

50 : Operação com Direito a Crédito - Vinculada Exclusivamente a Receita Tributada no
Mercado Interno

51 : Operação com Direito a Crédito - Vinculada Exclusivamente a Receita Não Tributada no
Mercado Interno

52 : Operação com Direito a Crédito - Vinculada a Receitas Tributadas e Não-Tributadas no
Mercado Interno

53 : Operação com Direito a Crédito - Vinculada Exclusivamente a Receitas de Exportação

54 : Operação com Direito a Crédito - Vinculada a Receitas Tributadas no Mercado Interno e
de Exportação

55 : Operação com Direito a Crédito - Vinculada a Receitas Não-Tributadas no Mercado
Interno e de Exportação

56 : Operação com Direito a Crédito - Vinculada a Receitas Tributadas e Não-Tributadas no
Mercado Interno, e de Exportação

60 : Crédito Presumido - Operação de Aquisição Vinculada Exclusivamente a Receita
Tributada no Mercado Interno

61 : Crédito Presumido - Operação de Aquisição Vinculada Exclusivamente a Receita Não
Tributada no Mercado Interno

62 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Tributadas e Não-
Tributadas no Mercado Interno

63 : Crédito Presumido - Operação de Aquisição Vinculada Exclusivamente a Receitas de
Exportação

64 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Tributadas e de
Exportação

65 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Não-Tributadas no
Mercado Interno e de Exportação

66 : Crédito Presumido - Operação de Aquisição Vinculada a Receitas Tributadas e Não-
Tributadas no Mercado Interno, e de Exportação

67 : Crédito Presumido - Outras Operações

70 : Operação de Aquisição sem Direito a Crédito

71 : Operação de Aquisição com Isenção

72 : Operação de Aquisição com Suspensão
    73 : Operação de Aquisição a Alíquota Zero

    74 : Operação de Aquisição sem Incidência da Contribuição

    75 : Operação de Aquisição por Substituição Tributária

    98 : Outras Entradas

    99 : Outras Operações

   Example: 07

   Aliquota number · double

   Alíquota do COFINS.
   Example: 3

   BaseCalculo number | null · double

   Base de Cálculo do COFINS. Quando não informado, é utilizado o valor dos produtos.
   Example: 1000

IBSCBS object

Informações relativas ao Imposto sobre Bens e Serviços (IBS) e à Contribuição sobre Bens e
Serviços (CBS), conforme a reforma tributária (Emenda Constitucional 132/2023).

   Informações relativas ao Imposto sobre Bens e Serviços (IBS) e à Contribuição sobre Bens e Serviços (CBS),
   conforme a reforma tributária (Emenda Constitucional 132/2023).

   CodClassificacaoTributaria string

   Código de Classificação Tributária (Padrão 000001).
   Example: 000001

   BaseCalculo number | null · double

   Base de cálculo do IBS/CBS.
   Example: 1000

   AliquotaIBSUF number | null · double

   Alíquota do IBS de competência das Unidades Federativas (UF).
   Example: 15

   AliquotaIBSMun number | null · double

   Alíquota do IBS de competência do Município.
   Example: 5

   AliquotaCBS number | null · double

   Alíquota da Contribuição sobre Bens e Serviços (CBS) de competência da União.
   Example: 8.5

   PercentualReducaoIBS number · decimal
      pRedAliq (gIBSUF/gIBSMun) - Percentual de redução da alíquota do IBS, usado no grupo gRed
      dos CST 011/200/515. Fixo por cClassTrib na tabela oficial (ex.: 100 para alimentação, 60 para
      educação/saúde). Quando omitido, é preenchido automaticamente pela tabela oficial.

      PercentualReducaoCBS number · decimal

      pRedAliq (gCBS) - Percentual de redução da alíquota da CBS. Pode divergir de
      PercentualReducaoIBS (ex.: 200025 = IBS 60 / CBS 100). Quando omitido, é preenchido
      automaticamente pela tabela oficial.

      PercentualDiferimento number · decimal

      pDif (gDif) - Percentual de diferimento, usado nos CST 510/515. Informado pelo contribuinte -
      não é fixo por cClassTrib. O valor diferido (vDif) é deduzido do IBS/CBS devido.

   Importacao object

   Detalhes do Imposto de Importação (II).

      Detalhes do Imposto de Importação (II).

      BaseCalculo number · double

      Base de Cálculo do Imposto de Importação.
      Example: 5000

      DespesasAduaneiras number · double

      Valor das despesas aduaneiras.
      Example: 200

      Valor number · double

      Valor do Imposto de Importação.
      Example: 750

      ValorIOF number · double

      Valor do IOF (Imposto sobre Operações Financeiras).
      Example: 50

nFCI string

Número de controle da FCI - Ficha de Conteúdo de Importação.
Example: B01F70AF-10BF-4B1F-848C-65FF57F616FE

Combustivel object

Detalhes de produtos combustíveis.

  Detalhes de produtos combustíveis.
   CodProdutoANP string

   Código do produto ANP.
   Example: 220102001

   DescricaoProdutoANP string

   Descrição do produto ANP.
   Example: GASOLINA C COMUM

   UFConsumo string

   UF do consumo.
   Example: MG

   PercentualGLP number · decimal

   pGLP - Percentual do GLP derivado do petróleo na composição do produto. Usado somente
   para GLP (código ANP 210203001); quando informados, a soma de PercentualGLP ,
    PercentualGasNaturalNacional e PercentualGasNaturalImportado deve ser 100 (rejeição
   855). Informe em pontos percentuais (ex.: 60 para 60%).
   Example: 60

   PercentualGasNaturalNacional number · decimal

   pGNn - Percentual de gás natural nacional (GLGNn) na composição do GLP. Somente para GLP
   (código ANP 210203001); entra na soma de 100 junto com PercentualGLP e
    PercentualGasNaturalImportado .

   Example: 30

   PercentualGasNaturalImportado number · decimal

   pGNi - Percentual de gás natural importado (GLGNi) na composição do GLP. Somente para GLP
   (código ANP 210203001); entra na soma de 100 junto com PercentualGLP e
    PercentualGasNaturalNacional .

   Example: 10

   ValorPartida number · decimal

   vPart - Valor de partida do GLP por quilograma, sem ICMS. Obrigatório para GLP (código ANP
   210203001); sem ele a SEFAZ rejeita com 856.
   Example: 4.85

DeclaracaoImportacao object

Informações da Declaração de Importação (DI/DSI/DIRE).

  Informações da Declaração de Importação (DI/DSI/DIRE).

   Numero string

   Número do Documento de Importação (DI, DSI, DIRE, ...).
   Example: 2512345678
DataRegistro string · date-time

Data de Registro do documento de importação.
Example: 2025-01-15T00:00:00-03:00

LocalDesenbaraco string

Local de Desembaraço Aduaneiro.
Example: Porto de Santos

UfDesenbaraco string

Sigla da UF onde ocorreu o Desembaraço Aduaneiro.
Example: SP

DataDesenbaraco string · date-time

Data do Desembaraço Aduaneiro.
Example: 2025-01-20T00:00:00-03:00

TipoViaTransporte integer · int32

Via de transporte internacional informada na Declaração de Importação.

Valores Possíveis:

1 : Marítima

2 : Fluvial

3 : Lacustre

4 : Aérea

5 : Postal

6 : Ferroviária

7 : Rodoviária

8 : Conduto / Rede Transmissão

9 : Meios Próprios

10 : Entrada / Saída ficta

11 : Courier

12 : Handcarry

Example: 1

ValorAFRMM number | null · double

Valor da AFRMM - Adicional ao Frete para Renovação da Marinha Mercante.
Example: 150

TipoIntermedio integer · int32

Forma de importação quanto a intermediação.
   Valores Possíveis:

    1 : Importação por conta própria

    2 : Importação por conta e ordem

    3 : Importação por encomenda

   Example: 1

   Cnpj string

   CNPJ do adquirente ou do encomendante.
   Example: 39658743000199

   Uf string

   Sigla da UF do adquirente ou do encomendante.
   Example: SP

   CodExportador string

   Código do Exportador.
   Example: EXP001

   CodFabricante string

   Código do Fabricante Estrangeiro.
   Example: FAB001

Exportacoes object[] · maxItems: 500

detExport - Exportação do item (até 500 por item): drawback e/ou exportação indireta. Na
exportação indireta (CFOP 7501 ou 3503) informe a chave da NF-e recebida com fim
específico de exportação; sem ela várias UFs rejeitam com 340 (Não informado o grupo de
exportação indireta no item).

   detExport - Exportação do item: drawback e/ou exportação indireta (exportInd). O grupo de exportação indireta é
   gerado quando há `ChaveAcessoNFe` ou `NumeroRegistroExportacao`.

   NumeroDrawback string

   nDraw - Número do ato concessório de Drawback (1 a 20 caracteres). Opcional.
   Example: 20250000123

   NumeroRegistroExportacao string

   nRE - Número do Registro de Exportação (até 12 dígitos). Opcional: desde a DU-E pode ficar
   vazio.
   Example:

   ChaveAcessoNFe string

   chNFe - Chave de acesso (44 dígitos) da NF-e recebida com fim específico de exportação.
   Obrigatória na exportação indireta (CFOP 7501 ou 3503).
   Example: 41261039658743000199550010000012341000012340

   QuantidadeExportada number · decimal

   qExport - Quantidade do item realmente exportada (até 4 casas decimais). Quando não
   informada, é usada a Quantidade do item.
   Example: 10

Rastros object[]

Rastreabilidade do produto (lote, validade, fabricação). Comum para medicamentos,
agrotóxicos e bebidas.

   Detalhes de rastreabilidade de um lote de produto.

   NumeroLote string · minLength: 1 · maxLength: 20

   Número do lote do produto (1-20 caracteres).
   Example: LOTE2025-001

   QuantidadeLote number · double

   Quantidade de produto no lote.
   Example: 100

   DataFabricacao string · date-time

   Data de fabricação/produção.
   Example: 2025-01-15T00:00:00-03:00

   DataValidade string · date-time

   Data de validade.
   Example: 2027-01-15T00:00:00-03:00

   CodigoAgregacao string

   Código de agregação (opcional).
   Example: AGR12345

Agropecuaria object

Informações de produtos agropecuários e florestais (NT 2024.003 - Grupo ZF).

Obrigatório a partir de 01/03/2026 quando o NCM cair em:

    01XXXXXX / 0301XXXX (animais vivos - GuiaTransito)
    06-12XXXX (vegetais primários - GuiaTransito, UFs ainda inativas)
    3808.52 a 3808.99 (defensivos - Defensivos)

Já obrigatório em BA, GO, MA, MT para NCM 0102XXXX (bovinos) desde 01/10/2025.
Informações de produtos agropecuários e florestais (NT 2024.003 - Grupo ZF). Obrigatório a partir de 01/03/2026
quando o NCM cair em: - 01XXXXXX / 0301XXXX (animais vivos - GuiaTransito) - 06-12XXXX (vegetais primários -
GuiaTransito, UFs ainda inativas) - 3808.52 a 3808.99 (defensivos - Defensivos) Já obrigatório em BA, GO, MA, MT
para NCM 0102XXXX (bovinos) desde 01/10/2025.

Defensivos object[]

Defensivos agrícolas aplicados (0 a 20). Cada item exige NumeroReceituario e
CpfResponsavelTecnico.

   Defensivo agrícola aplicado ao produto. Ambos os campos são obrigatórios.

   NumeroReceituario string · minLength: 1 · maxLength: 30 · required

   Número da receita ou receituário do agrotóxico/defensivo agrícola (1-30 caracteres).
   Example: REC-2026-0001

   CpfResponsavelTecnico string · minLength: 11 · maxLength: 11 · required

   CPF (11 dígitos) do engenheiro agrônomo, florestal ou técnico agrícola responsável.
   Example: 00000000000

GuiaTransito object

Guia de trânsito sanitário (animal, vegetal ou florestal) que autoriza o transporte.

   Guia de trânsito sanitário (animal, vegetal ou florestal) que autoriza o transporte.

   TipoGuia integer · min: 1 · max: 7 · required

   Tipo da guia de trânsito.

   Valores Possíveis:

    1 : GTA (Guia de Trânsito Animal)

    2 : TTA (Termo de Trânsito Animal)

    3 : DTA (Documento de Transferência Animal)

    4 : ATV (Autorização de Trânsito Vegetal)

    5 : PTV (Permissão de Trânsito Vegetal)

    6 : GTV (Guia de Trânsito Vegetal)

    7 : Guia Florestal (DOF, SisFlora-PA/MT, SIAM-MG)

   Example: 1

   UfGuia string · minLength: 2 · maxLength: 2 · required

   Sigla da UF emissora da guia (2 caracteres).
   Example: MG

   NumeroGuia string · minLength: 1 · maxLength: 9 · required
         Número da guia (1-9 dígitos).
         Example: 12345

         SerieGuia string · maxLength: 9

         Série da guia (1-9 dígitos). Opcional.
         Example: A

   ChaveAcessoReferenciada string

   Chave de acesso (44 dígitos) da NF-e ORIGINAL que este item está devolvendo. Usado apenas
   em NF-e de devolução (Finalidade = 4, Reforma Tributária / NT 2025.002). Quando preenchida,
   o item é referenciado pelo grupo DFeReferenciado (por item) em vez do NFReferencia (nível
   nota) - os dois não podem coexistir.

   NItemReferenciado integer

   Número do item (nItem) na NF-e ORIGINAL a que este item de devolução corresponde. É o
   número do item na nota de venda original, NÃO o número do item nesta devolução. Opcional;
   acompanha ChaveAcessoReferenciada.

Pagamentos object[]

Lista de pagamentos efetuados.

  Detalhes das informações de Pagamento.

   IndicadorPagamento integer · int32

   Indicador da forma de pagamento.

   Valores Possíveis:

   0 : A vista

   1 : Prazo

   Example: 0

   Desconto number · double

   Valor do desconto no pagamento.
   Example: 10

   Descricao string

   Descrição do meio de pagamento (xPag). Só vai para o XML quando FormaPagamento é 99
   (Outros); se omitida nesse caso, sai "Outros". Nas demais formas é ignorada.
   Example: Pagamento via PIX

   FormaPagamento string

   Forma de Pagamento utilizada.
Valores Possíveis:

01 : Dinheiro

02 : Cheque

03 : Cartão de Crédito

04 : Cartão de Débito

05 : Cartão da Loja (Private Label), Crediário Digital, Outros Crediários

10 : Vale Alimentação

11 : Vale Refeição

12 : Vale Presente

13 : Vale Combustível

14 : Duplicata Mercantil

15 : Boleto Bancário

16 : Depósito Bancário

17 : Pagamento Instantâneo (PIX) - Dinâmico

18 : Transferência Bancária, Carteira Digital

19 : Programa de fidelidade, cashback, crédito virtual

20 : Pagamento Instantâneo (PIX) - Estático

21 : Crédito em Loja

22 : Pagamento Eletrônico não Informado - falha de hardware

23 : Pagamento Instantâneo (PIX) - Automático

24 : TEF Book Transfer

90 : Sem pagamento

91 : Pagamento Posterior

99 : Outros

Example: 17

VlPago number · double

Valor pago.
Example: 2470

VlTroco number · double

Valor troco.
Example: 0

DataPagamento string | null · date-time
Data do pagamento (dPag - NT 2023.004). Opcional.

CNPJPagamento string

CNPJ do estabelecimento onde o pagamento foi processado/recebido (CNPJPag - NT
2023.004). Informar junto com UFPagamento (os dois ou nenhum). Opcional.

UFPagamento string

UF do estabelecimento onde o pagamento foi processado (UFPag - NT 2023.004). Opcional.

TipoIntegracao boolean

Pagamento integrado com automação? (TEF).
Example: false

CNPJCredenciadora string

CNPJ da credenciadora de cartão, se aplicável.
Example: 12345678000199

BandeiraOperadora string

Bandeira da operadora.

Valores Possíveis:

01 : Visa

02 : Mastercard

03 : American Express

04 : Sorocred

05 : Diners Club

06 : Elo

07 : Hipercard

08 : Aura

09 : Cabal

99 : Outros

Example: 01

NumeroAutorizacao string

Número da autorização da transação.
Example: A123456

CNPJRecebedor string

CNPJ do beneficiário do pagamento (CNPJReceb - NT 2023.004). Opcional.

IdTerminalPagamento string
   Identificador do terminal de pagamento (idTermPag - NT 2023.004). Opcional, 1-40 caracteres.

Cobranca object

Detalhes de Fatura e Parcelas para cobrança.

   Detalhes de Fatura e Parcelas para cobrança.

   Fatura object

   Detalhes da Fatura.

      Detalhes da Fatura.

      Numero string

      Número da fatura.
      Example: FAT0001

      Valor number · double

      Valor da fatura (Valor Bruto).
      Example: 2500

      Desconto number · double

      Desconto da fatura.
      Example: 50

      ValorLiquido number · double

      Valor liquido da fatura.
      Example: 2450

   Parcelas object[]

   Lista de Parcelas da Cobrança.

      Detalhes de uma Parcela de Cobrança.

      Vencimento string · date-time

      Vencimento da parcela.
      Example: 2025-07-01T00:00:00-03:00

      Valor number · double

      Valor da parcela.
      Example: 816.67
Transporte object

Informações sobre o Transporte e Frete.

   Informações sobre o Transporte e Frete.

   ModalidadeFrete integer · int32

   Modalidade de contratação do frete.

   Default automático
   Se Transporte não for informado, a API assume modFrete = 9 (sem frete). Para contratação
   efetiva de frete, envie o bloco Transporte com ModalidadeFrete entre 0–4 e os dados da
   transportadora.

   Valores Possíveis:

    0 : Contratação do Frete por conta do Remetente (CIF)

    1 : Contratação do Frete por conta do Destinatário (FOB)

    2 : Contratação do Frete por conta de Terceiros

    3 : Transporte Próprio por conta do Remetente

    4 : Transporte Próprio por conta do Destinatário

    9 : Sem Ocorrência de Transporte

   Example: 0

   NmTransportador string

   Nome ou Razão Social do(a) transportador(a).
   Example: Transportadora Expresso Ltda

   CNPJ string

   CNPJ do(a) transportador(a).
   Example: 00123456000199

   NmMunicipio string

   Nome do município do transportador.
   Example: São Paulo

   DsEndereco string

   Descrição do endereço do transportador.
   Example: Rua das Transportadoras, 50

   IE string

   Inscrição estadual do transportador.
   Example: 123456789012
UF string

Sigla da Unidade Federativa do transportador.
Example: SP

Vagao string

Descrição do vagão (se aplicável, modal ferroviário).
Example: Vagao123

Balsa string

Descrição da balsa (se aplicável, modal aquaviário).
Example: BalsaABC

Veiculo object

Detalhes do Veículo de Tração.

   Detalhes do Veículo de Tração.

   Placa string

   Placa do veículo.
   Example: ABC1234

   UF string

   Unidade Federativa do veículo.
   Example: SP

   RNTC string

   Registro Nacional de Transporte de Carga do veículo.
   Example: 99999999

Reboque object[]

Lista de Reboques/Carretas.

   Detalhes do Reboque/Carreta.

   Placa string

   Placa do reboque.
   Example: DEF5678

   UF string

   Unidade Federativa do reboque.
   Example: MG

   RNTC string
       Registro Nacional de Transporte de Carga do reboque.
       Example: 88888888

   Volumes object[]

   Lista de Volumes transportados.

      Detalhes de um Volume da Carga.

       Numero string

       Número do volume.
       Example: VOL001

       QuantidadeVolume integer · int32

       Quantidade de volumes da carga.
       Example: 5

       Especie string

       Espécie da carga.
       Example: CAIXAS

       Marca string

       Marca da carga.
       Example: PROD-A

       PesoBruto number · double

       Peso bruto da carga.
       Example: 150.5

       PesoLiquido number · double

       Peso liquido da carga.
       Example: 145

       Lacres string[]

       Lista de Lacres da carga.

EnviarEmail boolean

Indica se deve enviar o e-mail da nota fiscal automaticamente ao destinatário após a
autorização.
Example: true

Entrega object

Informações do local de Entrega (se diferente do Destinatário).
   Informações do local de Entrega (se diferente do Destinatário).

   CpfCnpj string

   CNPJ ou CPF do local de entrega.
   Example: 12345678901

   Nome string

   Nome do Entregador ou da pessoa/empresa no local de entrega.
   Example: Filial de Entrega

   Ie string

   Inscrição Municipal ou Estadual do local de entrega.
   Example: 987654321

   Endereco object

   Detalhes do Endereço de Entrega.

   Contato object

   Informações de Contato para a Entrega.

Exporta object

Informações referente a exportação.

   Informações referente a exportação.

   LocalDespacho string

   Descrição do local de despacho.
   Example: Galpao

   UFSaidaPais string

   Sigla da UF de Embarque ou de transposição de fronteira.
   Example: SP

   LocalEmbarqueTransp string

   Descrição do Local de Embarque ou de transposição de fronteira.
   Example: Sao Paulo

Retencoes object

Retenções federais totais da nota (IRRF, PIS/COFINS/CSLL retidos, Previdência). Gera a tag
 retTrib no XML.

   Retenções federais totais da nota (IRRF, PIS/COFINS/CSLL retidos, Previdência). Gera a tag `retTrib` no XML.
   BaseCalculoIRRF number | null · double

   Base de cálculo do IRRF.
   Example: 1000

   ValorIRRF number | null · double

   Valor retido do IRRF.
   Example: 15

   ValorRetidoPIS number | null · double

   Valor retido de PIS.
   Example: 6.5

   ValorRetidoCOFINS number | null · double

   Valor retido de COFINS.
   Example: 30

   ValorRetidoCSLL number | null · double

   Valor retido de CSLL.
   Example: 10

   BaseCalculoRetencaoPrevidencia number | null · double

   Base de cálculo da retenção da Previdência Social.
   Example: 1000

   ValorRetencaoPrevidencia number | null · double

   Valor da retenção da Previdência Social.
   Example: 110

ValorFrete number | null · decimal

Valor total do frete da nota. Quando informado, é distribuído proporcionalmente entre os itens
(proporção pelo ValorTotal de cada item), SUBSTITUINDO o ValorFrete informado em cada
produto. Não informado (nulo) = o frete de cada item é usado como enviado.
Example: 25.5

ValorDesconto number | null · decimal

Valor total do desconto da nota. Quando informado, é distribuído proporcionalmente entre os
itens (proporção pelo ValorTotal de cada item), SUBSTITUINDO o ValorDesconto informado em
cada produto. Não informado (nulo) = o desconto de cada item é usado como enviado.
Example: 50

ValorTotal number | null · decimal

Valor total esperado da nota (vNF), usado apenas para validação. Quando informado e
diferente do valor total calculado (produtos - descontos + frete + seguro + outras despesas +
 impostos que compõem o total), a emissão é bloqueada e o erro detalha o cálculo. Não
 informado (nulo) = sem validação.
 Example: 1500.5

Responses

 200   Successful operation

 Estrutura completa de retorno da Nota Fiscal Eletrônica.

 Base64Xml string

 XML da nota fiscal codificado em Base64.
 Example: PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPG5mZS...

 Base64File string

 Arquivo da nota fiscal (ex: PDF/DANFE) codificado em Base64.
 Example: JVBERi0xLjcKJeLjz9MKMSAwIG9iajw8L1R5cGUvQ2F0YWxvZy9QYWdlcyAy...

 ReturnNF object

 Informações de retorno e valores da Nota Fiscal.

    Informações de retorno e valores da Nota Fiscal.

    Numero integer · int64

    Número da nota fiscal.
    Example: 123456

    Serie integer · int64

    Série da nota fiscal autorizada.
    Example: 1

    ChaveNF string · minLength: 44 · maxLength: 44

    Chave de acesso da NF (44 dígitos).
    Example: 35231012345678901234550010001234561234567890

    NumeroProtocolo string

    Número do protocolo de autorização atribuído pela SEFAZ ao documento fiscal.
    Example: 135230000123456

    CodTipoAmbiente integer

    Código do Tipo do ambiente de processamento.

    Valores Possíveis:
1 : Produção

2 : Homologação

Example: 1

DsTipoAmbiente string

Descrição do ambiente (Produção ou Homologação).

Valores Possíveis:

0 : Produção

1 : Homologação

Example: Produção

CodStatusRespostaSefaz integer

Código do status de resposta retornado pela SEFAZ (ex: 100 - Autorizado o uso da NF-e).
Example: 100

DsStatusRespostaSefaz string

Descrição do status retornado pela SEFAZ.
Example: Autorizado o uso da NF-e

Ok boolean

Indica se a nota foi processada e autorizada com sucesso (true) ou se houve falha/rejeição
(false).
Example: true

Detalhes object

Informações de valores monetários e impostos da NF.

   Informações de valores monetários e impostos da NF.

   valorNf number · float

   Valor total da NF.
   Example: 1500.55

   valorIcms number · float

   Valor total do ICMS (Imposto sobre Circulação de Mercadorias e Serviços).
   Example: 180.06

   valorIpi number · float

   Valor total do IPI (Imposto sobre Produtos Industrializados).
   Example: 45

   valorPis number · float

   Valor total do PIS (Programa de Integração Social).
      Example: 9.75

      valorCofins number · float

      Valor total do COFINS (Contribuição para o Financiamento da Seguridade Social).
      Example: 45

Error string

Mensagem de erro do Brasil NFe quando a operação falha. Vazia em caso de sucesso.
Example:

Avisos string[]

Lista de avisos não-bloqueantes da emissão (vazia em sucesso sem ressalvas).
Example: []
Transmitir NFe em Lote
```
