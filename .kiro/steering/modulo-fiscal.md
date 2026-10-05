---
inclusion: manual
---

# Módulo Fiscal — Design e Decisões

> Contexto salvo do estudo de arquitetura do módulo fiscal. Referencie com #modulo-fiscal quando voltar ao tema.
> ERP Rails (Móveis Rosa). Simples Nacional. Emite NF-e (55) e NFC-e (65). Provedor: **Brasil NFe (plano Solo)** — escolhido por emissão ilimitada 55/65 + devoluções; adapter isola a escolha (reversível). Visão multiempresa + preparação reforma tributária (IBS/CBS).

---

# DOC BrasilNFe — EnviarNotaFiscal (payload de emissao, confirmado)
POST /EnviarNotaFiscal. Campos-chave (camelCase do provedor):
- Topo: Serie/Numero/Lote/Codigo (vazio=auto), DataEmissao/DataEntradaSaida, NaturezaOperacao,
  ModeloDocumento (55/65), Finalidade (1 normal,2 complementar,3 ajuste,4 DEVOLUCAO,5 cred,6 deb),
  TipoAmbiente ("1"/"2"), ConsumidorFinal, IndicadorPresenca, IdentificadorInterno,
  **NFReferencia: [chaves 44 dig]** (SO chave NF-e/NFC-e; modelo 1/1A/2 em papel NAO tem campo nesta API),
  ValorFrete, ValorTotal (validacao), Cliente{}, Produtos[], Pagamentos[], Cobranca{}, Transporte{}.
- Produto: NmProduto, CodProdutoServico, EAN, NCM, CEST, UnidadeComercial, Quantidade,
  ValorUnitario, ValorTotal, ValorDesconto/Seguro/Frete/OutrasDespesas, CFOP, OrigemProduto,
  **ChaveAcessoReferenciada + NItemReferenciado** (ref item a item), Imposto{}.
- Imposto.ICMS: CodSituacaoTributaria(CSOSN/CST), AliquotaICMS, BaseCalculo, ValorIcms, STRetido{...}, FCP...
  Imposto.IPI: CodEnquadramento, CodSituacaoTributaria, Aliquota, **ValorIpiDevolvido, PercentualMercadoriaDevolvida** (devolucao).
  Imposto.PIS/COFINS: CodSituacaoTributaria, Aliquota, BaseCalculo. Imposto.IBSCBS (reforma).
- IMPORTANTE: aceita VALORES destacados (BaseCalculo/ValorIcms) -> da p/ ESPELHAR impostos da nota de entrada na devolucao.
- Resposta: Base64Xml, Base64File, ReturnNF{ Numero, Serie, ChaveNF, NumeroProtocolo, CodStatusRespostaSefaz, DsStatusRespostaSefaz, Ok, Detalhes{} }, Error, Avisos[].
- Lote assincrono: /EnviarNotaFiscalLote (webhook nfe.lote.finalizado) — nao usado ainda.

---

# ESTADO ATUAL (atualizado — leia isto primeiro)

> As seções mais abaixo são o DESIGN histórico (Fatia 1). Esta seção reflete o que
> está REALMENTE implementado na branch `modulo-fiscal` (nunca em produção/master).

## Como está hoje (implementado e commitado em `modulo-fiscal`)

**Classificação fiscal (Fatia 1):** perfil_tributario + operacao_fiscal + regra_fiscal.
Produto aponta `cod_perfil_tributario`. Regra resolve por operacao + UF destino + tipo_cliente
(curinga `*`; específico vence genérico via `regra_para`). CFOP guardado como BASE (3 díg),
dígito 5/6/7 resolvido por `RegraFiscal.cfop_por_uf`. CRUD de perfis/regras com abas por imposto
(ICMS→IPI→PIS→COFINS→IBS/CBS). Relatório de pendências fiscais (produtos sem NCM/perfil/origem).

**Config + provedor:** `FiscalConfig` por empresa (ativo? define o módulo). `FiscalService`
(interface neutra) + `Fiscal::BrasilNfeAdapter` (emitir/devolver implementados; **cancelar
implementado** via POST /CancelarNotaFiscal — mas endpoint/campos ainda a confirmar na doc 2.0;
carta_correcao/inutilizar/consultar = NotImplementedError). Token em credentials
(`brasilnfe_token`, `brasilnfe_ambiente: homologacao`).

**Builder + emissão:** `Fiscal::DocumentoFiscalBuilder` monta documento neutro (cliente,
produtos com Imposto do perfil, CFOP por UF). `Fiscal::EmissorFiscal` orquestra: cria/reaproveita
documento, **valida dados fiscais ANTES de enviar** (trava: bloqueia se faltar NCM/CFOP/CSOSN —
em homologação a SEFAZ autoriza nota incompleta e mascara o erro), chama o provedor, persiste
resultado. Reemissão REAPROVEITA o mesmo documento (rejeitada/erro/rascunho/enviada); se já
autorizada, não reemite (JaAutorizada).

**Persistência:** `documento_fiscal` (máquina de estados rascunho→enviada→autorizada/rejeitada/
cancelada/erro; chave/protocolo/xml/danfe base64). `documento_fiscal_evento` (tem cod_funcionario
agora) grava eventos. `DocumentoFiscal#cancelar!` chama provedor + grava evento (quem/quando/motivo,
justificativa ≥15) e só muda status se SEFAZ homologar. `aplicar_resultado!` → quando autorizada,
`sincronizar_venda!` grava `numeronf` + `datanf` NA VENDA (não nos itens — ver pendências).

## VENDA REESTRUTURADA (grande mudança desde o design)
- `new` e `edit` usam o MESMO `_form_sales` (editável). Aposentados `editar_itens`/`atualizar_itens`
  e `_list_sales` (deletados). Rota `:update` adicionada.
- Persistência via **nested attributes** (não mais clear+rebuild): item/conta com `id` → UPDATE;
  sem id → INSERT; `_destroy` → DELETE. O trigger de estoque do banco cuida de tudo
  (delta de quantidade, troca de cor, troca de produto). `reject_if` nunca descarta registro com id.
- Normalização monetária BR centralizada: concern `MoedaBr` (setters aceitam "1.234,56" → BigDecimal)
  em Itemvenda/Contaspagrec/Venda.
- Travas de edição: venda CANCELADA ou com NF-e AUTORIZADA não edita (`Venda#editavel?`,
  `nfe_autorizada?`). Contas com lançamento no caixa ficam read-only (removidas do params_venda_update).

## EMISSÃO NA TELA DE VENDA (UX atual)
- Rodapé do form: botão VERDE (salvar) + botão AZUL redondo (salvar e emitir/reemitir, tooltip
  dinâmico conforme status da última NF; some se já autorizada). Azul marca `emitir_nfe=1` e o
  controller emite após salvar (`emitir_nfe_apos_salvar?`).
- Indicador de perfil fiscal por item (abaixo do produto): texto pequeno azul (nome do perfil) /
  vermelho ("Sem perfil fiscal"); só aparece com produto selecionado. Clica → modal escolhe o
  Perfil Tributário e grava direto no produto via AJAX (`ProdutoPerfilFiscalController`).
- Relatório de vendas (`rep_sales`): botão "i" abre detalhe inline da venda em ABAS (Produtos/Contas,
  accordion — abrir uma fecha as outras). Item "Espelho NF (PDF)" gera um PDF espelho via WickedPdf
  (`espelho_pdf.html.erb`) — sem valor fiscal, só conferência. Ações fiscais (DANFE/cancelar NF/
  cancelar NF+venda/reemitir) no menu, conforme status. DataTables REMOVIDO dessa tabela (conflitava
  com as linhas de detalhe colspan).
- Cancelamento tem escopo: "nf" (só a NF) ou "ambos" (NF + venda, estorna estoque+contas via caixa).

## GATE (importante)
- Tudo fiscal está atrás de `empresa_tem_modulo_fiscal? && access_control.super_admin?` (gate
  TEMPORÁRIO — só o Jonas vê, enquanto testa). Decisão combinada: depois trocar por SÓ
  `empresa_tem_modulo_fiscal?` (libera pra qualquer usuário da empresa com o módulo). AINDA NÃO feito.
- Empresa piloto: cod_empresa 2 (MR MARIPA), UF PR, FiscalConfig ativo (homologacao, brasilnfe).

## DECISÕES QUE MUDARAM / CONFIRMADAS depois do design
- Foco virou **NF-e 55 na tela de venda** (tela com cliente), NÃO NFC-e 65 no balcão. NFC-e 65 fica
  pra futuro (tela de balcão). Produção NFC-e está "Desativado" (plano não contratado); homologação ok.
- **Origem NÃO é obrigatória**: o builder usa `origem || "0"` (Nacional) como padrão. A trava de
  emissão exige só NCM/CFOP/CSOSN (origem só vira aviso). Igual ao sistema atual do usuário.
- **Checkbox "NF por item"** (do design, seção abaixo): NÃO será feito na venda. Decisão do usuário:
  criar 2 telas separadas de **emissão avulsa** de NF-e e NFC-e (sem venda). Pendente/futuro.

## DECISÃO: qtdfiscal (estoque fiscal) controlado pelo RAILS na emissão
Contexto: `qtdfiscal` tem ENTRADA (compra) e SAÍDA (venda/NF).
- **ENTRADA** continua pela trigger de COMPRA (`tgrf_estoquecompra` em itemcompra). O outro
  sistema legado ainda faz compras no mesmo banco e depende dessa trigger — NÃO TOCAR nela.
- **SAÍDA** sai da trigger de VENDA (`tgrf_estoquevenda`) e passa a ser controlada pelo RAILS
  no momento da EMISSÃO da NF (venda e avulsa), respeitando `regra_fiscal.controla_estoque`
  ("proprio" baixa qtdfiscal / "nao_controla" não baixa). Cancelamento estorna.
- Por que é seguro: hoje a trigger de venda só baixava qtdfiscal se itemvenda.numeronf>0, mas a
  venda nasce sem numeronf — então na prática quase nunca baixava. Mover pro Rails corrige isso.
- `controla_estoque` é por REGRA (não por produto): o mesmo produto pode controlar ou não,
  conforme a operação/regra que casar.
- Estoque FÍSICO (`quantidade`) continua 100% na trigger de venda — só o qtdfiscal sai de lá.
- Futuro: importar qtdfiscal atualizado do sistema de notas do usuário (Rails vira dono do número).
- Futuro (compra): adicionar campo "número do pedido" na compra.

## NF AVULSA = 100% FISCAL (decisão)
- Não gera venda, não cria itemvenda, NÃO mexe no estoque físico. Só documento_fiscal + qtdfiscal.
- Duas telas separadas (campos obrigatórios diferentes):
  - **NF-e 55 avulsa**: destinatário OBRIGATÓRIO (CPF/CNPJ + nome + endereço).
  - **NFC-e 65 avulsa**: só produtos + valores; CPF OPCIONAL ("consumidor não identificado").
- Builder/Emissor precisam ser generalizados para aceitar itens+destinatário "soltos" (sem venda).

## EMISSÃO AVULSA — FEITA ✅
- Telas em `notas_avulsas` (NotasAvulsasController): index (lista docs cod_venda nil),
  new (seletor 55/65), create, show, danfe, cancelar, cores_produto. Menu "Notas Avulsas".
- 55 exige destinatário (cod_pessoa); 65 destinatário opcional (consumidor não identificado).
- Fonte neutra: Fiscal::DocumentoAvulso (duck-typed como Venda, cod_venda=nil). Reusa builder+emissor.
- qtdfiscal baixado pelo EstoqueFiscalService na emissão (respeita controla_estoque); estorna no cancelar.
- NÃO há espelho pós-emissão (doc avulso não persiste itens; usar DANFE/XML).

## DEVOLUCAO DE COMPRA — REFORMULADA ✅ (modelo operacao-no-topo + perfil-por-item)
- Botao "Emitir Devolucao (NF-e)" em compras#show (super_admin+modulo, compra nao cancelada).
- CollaboratorsBackoffice::DevolucoesCompraController (new=revisao/planilha, create=emite,
  previsualizar=DANFE via AJAX, resolver_cfop=AJAX). Rota aninhada compras/:compra_id/devolucao.
- Fiscal::DevolucaoCompraExtractor: le XML da compra (compra.xml_file) -> itens com impostos
  destacados (ICMS/IPI/PIS/COFINS: cst/base/aliquota/valor). Chave de referencia do filename do
  blob (NFe+44). Fallback itemcompra se sem XML.

### Modelo de resolucao (confirmado pelo usuario)
- **Topo da tela = OPERACAO da NF** (select `operacaoGeral`). Lista TODAS as operacoes ativas
  (`OperacaoFiscal.ativos`), inclusive tipo=entrada (ex. "Devolucao de venda"), pois a regra do
  perfil pode usar qualquer operacao. O `tipo` da operacao e so catalogo — NAO vira TpNF no XML.
- **Por item = PERFIL tributario** (select `.dev-perfil`, trocavel; default = perfil do produto).
- **CFOP + CST/CSOSN saem da REGRA** `(perfil + operacao do topo + UF)`. Sem regra para essa
  combinacao, CFOP fica EM BRANCO (nao converte CFOP do XML — fallback removido). Resolve via
  Fiscal::CfopResolver.cfop(produto, operacao, perfil:) e regra_para(...).
- **Tributacao HIBRIDA** (DevolucaoCompraBuilder#montar_imposto_hibrido): CST/CSOSN + aliquotas da
  REGRA; VALORES (base/valor ICMS, IPI, PIS/COFINS base) do XML da compra, rateados por quantidade
  e EDITAVEIS na tela (colunas ICMS%/ICMS Base/ICMS R$/IPI%/IPI R$). Override vazio+auto = zera.
- qtdfiscal baixa (mercadoria sai) via EmissorFiscal#baixar_estoque_fiscal -> EstoqueFiscalService.

### SENTIDO DA NF = CFOP (nao o tipo da operacao)
- O provedor Brasil NFe NAO recebe TpNF; o sentido (entrada 1/2/3 vs saida 5/6/7) vem do 1o digito
  do CFOP de cada item. Devolucao de compra sempre sai 5/6/7. cfop_por_uf resolve 5/6/7 por UF.

### DESTAQUE DE ICMS no SIMPLES = CSOSN 900 (nao CST)
- Empresa e Simples (CRT 1). Para DESTACAR ICMS numa devolucao (como a NF real HENN: ICMS 12%,
  IPI 3,25%, CFOP 6202) usa-se **CSOSN 900** (grupo ICMSSN900). A DANFE imprime "090" por
  convencao visual, mas no XML e CSOSN 900. CST (ex. 090/51) e so regime normal — o provedor
  REJEITA CST com emitente Simples ("CSOSN invalido para Simples/MEI").
- ARMADILHA ja vivida: regra gravada com "90" (2 digitos) rejeita — CSOSN tem 3 digitos (900).
  A tabela CST_ICMS no helper tinha "90" e "090" juntos, confundia; corrigir campo da regra p/ 900.
- Sem regra, o builder NAO deve espelhar o CST cru do XML (vira CST incompativel com Simples) —
  pendente decidir fallback (bloquear exigindo regra vs CSOSN seguro). Com regra CSOSN 900, ok.

### IE do destinatario / HOMOLOGACAO
- Destinatario = fornecedor. Com IE no cadastro -> contribuinte: IndicadorIe 1 + IE,
  consumidor_final=false. Sem IE -> IndicadorIe 9, consumidor_final=true (evita rejeicao 696).
  Criterio e so "tem IE?", NAO olha ambiente (igual a NF real HENN: destinatario contribuinte).
- Em HOMOLOGACAO a SEFAZ NAO valida IE real: a DANFE de pre-visualizacao mostra a IE "errada" e,
  se a nota DESTACA ICMS, da conflito (rejeicao "IE invalida" com contribuinte, OU rejeicao 600
  "CSOSN incompativel com Nao Contribuinte" se forcar IndicadorIe 9). As duas rejeicoes sao
  mutuamente exclusivas em teste — e LIMITACAO do ambiente, nao bug. Em PRODUCAO a IE real e
  valida e o destaque e coerente (a NF real HENN prova). Validar emissao com destaque em producao.
- NAO tentar "ajustar IE so em homologacao" (ja testado: forcar IndicadorIe 9 quebra o CSOSN 900 —
  rejeicao 600). Revertido.

### Outros
- EmissorFiscal aceita builder injetado + cod_compra:. documento_fiscal.cod_compra vincula a compra.
  validar_dados_fiscais RELAXA p/ finalidade 4 (so exige CFOP estrutural).
- Perfil tributario ganhou coluna `tipo` (saida/entrada), scopes de_saida/de_entrada. Seletor de
  perfil por item usa de_saida.
- LIMITACAO: referencia so por CHAVE NF-e (API nao tem campo p/ NF modelo 1/1A/2 em papel).
- VALIDADO em homologacao com XML real: pre-visualizacao OK com CSOSN 900 + ICMS destacado
  (compra 30218, fornecedor HENN). Emissao real com destaque = fazer em producao.

## PENDÊNCIAS (não feito ainda)
1. Trocar gate `super_admin` → só `empresa_tem_modulo_fiscal?` quando liberar pra outros.
3. Fix do trigger `tgrf_estoquevenda` (coluna ambígua `quantidade` no ramo de alteração de
   quantidade) foi aplicado MANUALMENTE pelo usuário em prod+local, mas NÃO está versionado numa
   migration — ambiente novo via schema:load traria o bug de volta. Versionar.
4. `qtdfiscal` na emissão: `sincronizar_venda!` grava numeronf na VENDA, não nos ITENS; o trigger
   só mexe em qtdfiscal quando itemvenda.numeronf>0. Ajuste de estoque fiscal na emissão fica pra
   depois (liga com as telas de emissão avulsa).
## EVENTOS NF-e/NFC-e no BrasilNfeAdapter (doc 2.0 confirmada) ✅
Endpoints base https://api.brasilnfe.com.br/services/fiscal, header Token, TipoAmbiente 1/2.
- **Cancelamento** POST /CancelarNotaFiscal: ChaveNF + Justificativa(15-1000) + NumeroProtocolo
  (so obrigatorio se nota emitida por OUTRO sistema). Prazo NF-e 24h / NFC-e 30min.
- **Carta de Correcao** POST /EnviarCartaCorrecao: TipoAmbiente + ChaveNF + Correcao(15-1000).
  So erros formais (nao valores/partes/datas/numero/serie). Implementado: carta_correcao(ref, texto).
- **Inutilizacao** POST /InutilizarNumeracao: TipoAmbiente + ModeloDocumento + Serie +
  NumeracaoInicial/Final + Justificativa. Implementado: inutilizar(serie:,numero_inicial:,numero_final:,justificativa:,modelo:).
- IMPORTANTE: resposta de EVENTO vem na RAIZ (DsMotivo/NuProtocolo/CodStatusRespostaSefaz/Status/
  Base64Xml/Base64File/Error), NAO em ReturnNF. Sucesso = Status==1 && cStat in [100,101,135,150,155].
  Mapeado por to_evento_result. (Bug anterior: lia de ReturnNF — corrigido.)
- Outros eventos da doc NAO implementados (ainda): Manifestacao do Destinatario
  (/ManifestarNotaFiscal), ECONF (/EnviarEconf), Eventos Reforma Tributaria (/EnviarEvento).
- Falta: UI p/ carta de correcao e inutilizacao (metodos no adapter prontos, sem tela ainda).
  consultar() ainda NotImplementedError.

## MARCO: EMISSÃO REAL FUNCIONANDO ✅
- O credenciamento do Brasil NFe como responsável técnico na SEFAZ-PR FOI FEITO
  (resolveu a antiga rejeição 974). **NF-e já foram emitidas e autorizadas de verdade.**
- Ou seja, o motor de emissão está validado ponta a ponta na SEFAZ real, não só homologação.

## DOC DO PROVEDOR (Brasil NFe) — consultar antes de mexer no adapter/payload
- PDFs e resumo em **docs/brasilnfe/** (README.md tem os fatos-chave extraidos).
  A doc online e renderizada por JS (nao da pra fetch); por isso guardamos os PDFs.
- Pontos que ja usamos de la:
  - Serie/Numero/Lote em branco => Brasil NFe numera automatico (empresa+modelo+
    serie+ambiente). Enviar so para controle manual (migracao / pular inutilizado).
  - **NFC-e (65) so aceita CFOPs: 5101,5102,5103,5104,5115,5405,5656,5667,5933,
    6108,6109,6110.** Fora disso = rejeicao 725 (CFOP invalido) / 386 (CFOP x CSOSN).
  - Rejeicao 787: NFC-e IndicadorPresenca=4 exige destinatario.
  - CSC NAO vai no payload do EnviarNotaFiscal — e do painel/empresa, por ambiente.
  - Pre-visualizacao NFC-e vem em HTML (nao PDF).

## Arquivos-chave (orientação rápida)
- services/fiscal/: emissor_fiscal.rb, documento_fiscal_builder.rb, brasil_nfe_adapter.rb; services/fiscal_service.rb, fiscal_result.rb
- models/: documento_fiscal.rb, documento_fiscal_evento.rb, perfil_tributario.rb, regra_fiscal.rb, operacao_fiscal.rb, fiscal_config.rb; concerns/moeda_br.rb; venda.rb (editavel?/nfe_autorizada?)
- controllers/collaborators_backoffice/: documentos_fiscais_controller.rb (emitir/espelho/cancelar/danfe/show), produto_perfil_fiscal_controller.rb, vendas_controller.rb (create/edit/update + emitir_nfe_apos_salvar?), perfis_tributarios/regras_fiscais/fiscal_config/fiscal_pendencias
- views: vendas/shared/_form_sales.html.erb, vendas/_itensvenda_fields.html.erb, documentos_fiscais/espelho_pdf.html.erb, report/rep_sales/index.html.erb + _venda_detalhe.html.erb + _fiscal_acoes.html.erb
- inflexão: documento_fiscal/perfil_tributario/regra_fiscal em config/initializers/inflections.rb (membros usam singular, ex: ..._documento_fiscal_path)

---

## Princípios

1. Produto NÃO guarda tributação; aponta para um **Perfil Tributário** (`perfil_tributario_id`). Muitos produtos → mesmo perfil.
2. Tributação real é resolvida por **contexto** (regime + UF destino + operação + tipo cliente), não campo fixo.
3. Multiempresa desde o modelo: toda tabela fiscal com `cod_empresa`; certificado/série/CSC por estabelecimento.
4. Provedor atrás de um **adapter** (`FiscalService`); provedor é detalhe substituível (Focus NFe OU Brasil NFe — não decidido).
5. Documento fiscal é **máquina de estados** (rascunho→enviada→autorizada→cancelada/rejeitada) com XML/chave/protocolo persistidos + eventos.
6. Espaço para **IBS/CBS** (cClassTrib) desde já, mesmo vazio.

## Entidades

- **perfil_tributario**: cadastro reutilizável (nome, descrição, ativo). Não contém CSOSN/CFOP.
- **operacao_fiscal**: tipo de movimento (venda, devolução venda, devolução compra, transferência...). Natureza + modelo 55/65.
- **regra_fiscal** (coração): `(empresa/regime + perfil + operacao + uf_destino + tipo_cliente) → CFOP base, CSOSN/CST, alíquotas, PIS/COFINS, cClassTrib`. `uf_destino` aceita curinga `*` e é usado só para EXCEÇÕES tributárias (alíquota/CST que muda por UF), não para CFOP.

### CFOP automático (decisão confirmada)
- A regra guarda o **CFOP base** (3 dígitos, ex: `102`), NÃO o CFOP completo.
- O primeiro dígito é resolvido na emissão comparando UF da empresa x UF do cliente:
  - mesma UF → `5` + base (ex: 5102)
  - UF diferente → `6` + base (ex: 6102)
  - exterior → `7` + base
- Helper puro: `cfop_por_uf(base, uf_empresa, uf_cliente)`.
- Isso elimina a necessidade de uma regra por UF só para variar CFOP; "uf_destino" fica só para exceções tributárias reais (raro no Simples).

### Demais entidades
- **fiscal_config**: por estabelecimento — regime, ambiente (homolog/prod), série+numeração NF-e/NFC-e, CSC/token NFC-e, referência ao certificado (nunca o .pfx no repo).
- **documento_fiscal**: status, chave 44díg, protocolo, número, série, xml_ref, origem (cod_venda/cod_compra).
- **documento_fiscal_evento**: cancelamento, carta de correção, manifestação (cada um com xml/protocolo).

## Decisão de UX (confirmada pelo usuário)
- Perfil e Regras são tabelas separadas no banco, mas **cadastradas na mesma tela** (perfil no topo, regras em tabela editável embaixo) — "como se fosse um só".
- **O produto vincula o PERFIL TRIBUTÁRIO** (um select), não a operação nem a regra. CSOSN/CFOP saem do cadastro do produto (viram legado). No produto ficam só: NCM, CEST, origem, GTIN e perfil_tributario_id.
- Botão "＋ Novo perfil" ao lado do select no produto, para criar sem sair da tela.

## Fluxo de emissão (confirmado)
Para cada item da venda:
1. Operação = definida pela ação (Venda / Devolução / ...).
2. Item → Produto → Perfil.
3. Dentro do perfil, seleciona a **regra que casa com a operação**.
4. Regra entrega CFOP base + CSOSN/CST + alíquotas + cClassTrib.
5. `cfop_por_uf` resolve o dígito (5 mesma UF / 6 outra UF / 7 exterior) comparando UF empresa x UF cliente.
6. Monta item; repete; monta payload; FiscalService(Focus) transmite.
Documento nasce em status "rascunho" (confere antes de transmitir).

## Emissão a partir da venda — verificação por item (decisão de UX)
- Nem todo produto pode entrar na NF (ex: mercadoria comprada sem nota / "vendedor de rua" → sem estoque fiscal).
- Na tela da venda, cada linha de item tem uma coluna **"NF" com checkbox**:
  - Item ok → checkbox marcado (entra na nota).
  - Item com problema → checkbox desmarcado automaticamente + ícone ⚠ com tooltip do motivo.
- Verificações por item (via AJAX ao adicionar o item): estoque fiscal (`qtdfiscal`), perfil tributário definido, NCM válido (≠ 00000000), origem preenchida, CFOP/CSOSN resolvíveis.
- Botões: "Só salvar" e "Salvar e emitir NF" (emite só os itens marcados). Resumo mostra total da venda x total na NF.
- Usuário pode remarcar manualmente (forçar), MAS: dar saída fiscal sem estoque fiscal é decisão do contador (risco fiscal). `qtdfiscal` existe justamente para esse controle. Confirmar com contabilidade a política de forçar.
- Mock: docs/fiscal/05-venda-nf-por-item.svg

## Emissão diferida (venda agora, nota depois) — decisão aprovada
- Venda e emissão de NF são momentos separados. Venda tem **status fiscal**: sem_nota / nota_pendente / nota_emitida.
- Cenário real: produto ainda vai chegar; cliente pode querer a nota na hora ou depois. Se ainda não há estoque fiscal, o item aparece desmarcado com ⚠ "aguardando entrada"; quando a mercadoria entra, emite.
- Lista/dashboard: filtro "vendas com NF pendente".

## Devolução de compra (Fatia 4) — fluxo definido pelo usuário
- Frequência: ~2/mês. Abordagem escolhida: **espelhar o XML da nota de compra original** (Opção 1).
- Fluxo: acha a NF de compra importada → "Devolver" → carrega itens do XML → marca total OU desmarca/exclui itens (parcial) → ajusta quantidade → sistema recalcula impostos destacados proporcionalmente (ICMS/ST/IPI/valores) → gera ESPELHO para conferência → confirma → emite NF de devolução referenciando a chave da NF original.
- Base já existe: itemcompra guarda icms, ipi, valorst, valorunitario, quantidade, valor_frete. XML importado disponível.
- Atenção no recálculo parcial: arredondamento de centavos e rateio de desconto/frete.
- Melhoria futura: guardar chave_acesso da NF de compra (hoje pode ler do XML na hora).

## NF avulsa (sem venda vinculada) — aprovada, com ressalva de estoque fiscal
- Emissão de NF independente, não nasce de uma venda do sistema. Casos: cliente quer nota depois, complemento fiscal, situações fora do fluxo de venda.
- **Afeta só o estoque fiscal (`qtdfiscal`), NÃO o estoque real** — o produto físico já saiu / não passa pelo estoque real.
- Modelada como uma **operação** ("NF avulsa") gerando documento_fiscal; baixa só qtdfiscal.
- Alternativa mais limpa que "trocar por similar": emite a nota do produto que realmente se quer notar.
- Ressalva: só deveria emitir de produto com `qtdfiscal` disponível. Emitir de produto sem estoque fiscal deixa qtdfiscal negativo (mesmo risco fiscal). Impedir vs. só avisar = política do contador.
- Garantia: usuário informou que ele mesmo presta garantia, então esse aspecto não é bloqueio no caso dele.

## Entradas (documentos recebidos)
- XML de fornecedores; Importação XML (manual); Notas recebidas (NF-e contra o CNPJ); Manifestação / distribuição; Devolução de compra.
- "Compras" e "Eventos" NÃO entram aqui: Compras é módulo do ERP; Eventos pertencem a Documentos Fiscais. Evita duplicação conceitual.

## Auditoria (camada transversal) — aprovada
- Não é um silo; observa os demais blocos e registra ações sensíveis: alterações tributárias (perfil/regra), emissões/cancelamentos, alterações de configuração (certificado, série, ambiente).
- Registro: quem / quando / antes→depois / tipo de evento.
- Manter simples: uma tabela genérica de auditoria + tela de consulta com filtros (sem versionamento complexo). Pode ser a tabela polimórfica que unifica produto_fiscal_logs + auditoria fiscal no futuro.
- Já existe base: produto_fiscal_logs é uma trilha de auditoria de mudança fiscal do produto.
- Entra no roadmap junto do acesso do contador (Fatia 5) — não auditar o que ainda não existe.

## UF de origem — vem da empresa emitente
- A UF de origem NÃO é campo da regra: sai do cadastro da empresa (endereço→cidade→estado). A empresa já está na chave da regra. Evita redundância/inconsistência.
- UF destino: só na regra como filtro de EXCEÇÃO tributária; para CFOP é resolvido por cfop_por_uf comparando origem(empresa) x destino(cliente).

## Matriz e filial
- Fiscalmente são ESTABELECIMENTOS distintos: mesmo CNPJ raiz (8 díg.), CNPJ completo diferente (sufixo 0001/0002...), IE própria, endereço/UF próprio, e **numeração/série de NF independentes**. A NF sai com CNPJ/IE/endereço do estabelecimento que vendeu.
- Banco atual já é multiempresa real: `empresa` tem cpf_cnpj, inscricaoestadual, endereco, cod_cidade(→UF); venda/compra/estoque/empresaproduto têm cod_empresa. Então matriz e filial = dois registros em `empresa` (dois cod_empresa).
- Design já cobre o essencial: `fiscal_config` por cod_empresa → série/numeração/CSC/certificado por estabelecimento (evita conflito de numeração que a SEFAZ rejeita).
- NÃO precisa estrutura nova agora.
- Direção futura preferida do usuário: tabela **`grupo`** + `empresa.cod_grupo` (mais flexível que auto-referência matriz/filial). Cobre tanto matriz+filiais (mesma raiz CNPJ) quanto grupo econômico (empresas com CNPJs de raízes diferentes, mesmo dono).
- IMPORTANTE: grupo é camada de ORGANIZAÇÃO/GESTÃO (relatórios consolidados, permissões, filtros), NÃO de emissão. Emissão continua SEMPRE por estabelecimento (cod_empresa): cada empresa emite com seu CNPJ/IE/série. O fiscal não deve amarrar nada ao grupo.
- Encaixe: filtro por grupo em Relatórios/Contador e Auditoria. Aditivo (1 tabela + FK opcional), sem refazer o fiscal. Transferência entre empresas do grupo = operação fiscal por par de empresas, não pelo grupo.

## NÃO usar "transações" do painel do provedor (decisão)
- O Brasil NFe (como o MyRP) permite cadastrar transações/tributação no painel deles. NÃO usar.
- Motivo: (1) amarra ao provedor — trocar de provedor perderia a config; (2) duas fontes de verdade (painel vs Perfil do sistema) = divergência; (3) ERP ficaria sem saber a tributação (perde autonomia/relatórios).
- Decisão: a fonte da tributação é o PERFIL TRIBUTÁRIO do nosso sistema; o adapter monta o Imposto (ICMS/CSOSN, CFOP...) no payload e manda pronto. Provedor só transmite. Terceiriza-se infra (certificado, comunicação SEFAZ), não a regra fiscal do negócio.

## PENDENTE — Ajustes no relatório de Pendências Fiscais (empresa piloto = 2)
Investigado (context-gatherer). Modelo real:
- Estoque é por **produto+cor+empresa** (empresaproduto: cod_empresa+cod_produto+cod_cor; varias linhas por produto, uma por cor). Estoque real via function_estoquereal / empresaproduto.quantidade.
- Dados fiscais (ncm, origem, csosn, perfil) ficam NO PRODUTO (nao variam por cor) -> pendencia fiscal por produto esta CORRETA. (empresaproduto.cest existe mas parece legado/nao usado — confirmar).
- Itemvenda referencia produto E cor (cod_cor) -> a linha da NF sai de um empresaproduto (produto+cor).
- Padrao do sistema p/ "vendavel": produto.ativo + empresaproduto.ativo + cores.ativo, sempre por cod_empresa (ver vendas_controller/compras_controller).

Ajustes a fazer no fiscal_pendencias_controller (hoje usa current_collaborator.cod_empresa e so quantidade>0):
1. **Seletor de empresa** (padrao empresa 2 = piloto), nao fixar na empresa do usuario logado.
2. Alinhar filtro de estoque ao padrao: exigir empresaproduto.ativo=true E cores.ativo=true E quantidade>0.
3. Manter deteccao de pendencia por produto; opcional: mostrar impacto por produto+cor.

## Adapter do provedor
`FiscalService`: emitir / consultar / cancelar / carta_correcao / inutilizar / devolver. Impl possíveis: FocusAdapter e/ou BrasilNfeAdapter.
PROVEDOR ESCOLHIDO: **Brasil NFe (plano Solo)**. Motivo: Solo tem emissão ILIMITADA de 55 e 65 + devoluções e demais operações no próprio plano. Focus (plano Retail/NFCe) tinha volume suficiente mas aparentemente sem devolução no plano — e devolução é usada. Decisão reversível: FiscalService/adapter isola; trocar de provedor = trocar adapter.
Confirmado na página oficial (brasilnfe.com.br/products/nf-e): emissão 55 com cancelamento, inutilização, carta de correção e DANFE via JSON. Devolução = emissão de NF-e normal com CFOP de devolução (1202/2202) referenciando a chave da nota original — não precisa endpoint dedicado; coberto pela emissão 55.
A confirmar antes de pagar: validar na doc técnica/homologação o payload de devolução (CFOP + ref da nota) e inutilização; ou perguntar ao suporte (anunciam 24/7) se está no plano Solo. Parte B: implementar BrasilNfeAdapter.

## Aproveitar do que já existe
- produto.ncm/cest/origem/gtin ficam no produto; **produto.csosn vira LEGADO/fallback** (substituído por perfil_tributario_id na migração suave).
- produto_fiscal_logs: trilha de mudança fiscal do produto.
- xml_storage / importação XML: reaproveitar para XML autorizado e entradas.
- estado (sigla+IBGE): UF destino nas regras.
- access_role_permission: papel "Contador" (read+export; edita classificação com auditoria; não edita documento emitido).
- venda/itemvenda, compra/itemcompra: origem dos documentos.

## Migração suave (sem big bang)
1. Introduzir perfil/operacao/regra sem remover csosn do produto (fallback).
2. Produto aponta perfil; sem perfil, usa campo legado.
3. Regras cobrindo tudo → legado deixa de ser usado.

## Roadmap em fatias
1. Perfil + Operação + Regra; vincular no produto/compra. (não emite)
2. Parte A (neutra): Fiscal Config + interface FiscalService. Parte B: adapter(s) em homologação (testar Focus e/ou Brasil NFe); 1 NFC-e teste em cada para decidir.
3. Emissão real NFC-e (balcão) + status/eventos + XML.
4. NF-e (55), devoluções, carta de correção, cancelamento.
5. Acesso contador + relatórios para contabilidade + **auditoria** (consulta de trilha).

## Pendências / riscos
- **Certificado .pfx exposto no Git** (working tree em public/assets + histórico). Ações: (a) revogar/reemitir com contador — tratar como comprometido; (b) `.gitignore` + `git rm --cached`; (c) limpar histórico (filter-repo/BFG, destrutivo, push --force). `.gitignore` não ignorava .pfx.
- Transações `idle in transaction` (cliente Hibernate externo) travam ALTER TABLE. Migrations fiscais grandes: janela + lock_timeout + disable_ddl_transaction!. Resolver raiz: idle_in_transaction_session_timeout no Postgres.
- Começar regras simples (padrão por perfil + poucas exceções). Não modelar todo ICMS-ST de uma vez.
- IBS/CBS: acompanhar com contador + Focus o que/quando preencher.

## Mockups das telas (estudo)

Imagens salvas em `docs/fiscal/`. São rascunhos de UI para discussão, não telas finais.

### 1. Cadastro de Perfil Tributário (perfil + regras na mesma tela)
![Perfil Tributário](../../docs/fiscal/01-perfil-tributario.svg)

### 2. Produto vinculado ao Perfil (o produto só aponta o perfil)
![Produto e Perfil](../../docs/fiscal/02-produto-perfil.svg)

### 3. Emissão de NFC-e (regras resolvidas automaticamente, CFOP 5/6/7 pela UF)
![Emissão NFC-e](../../docs/fiscal/03-emissao-nfce.svg)

### 4. Dashboard Fiscal
![Dashboard Fiscal](../../docs/fiscal/04-dashboard-fiscal.svg)

### 5. Venda com verificação de NF por item (checkbox + alerta inline)
![Venda NF por item](../../docs/fiscal/05-venda-nf-por-item.svg)

## Diagramas

### Diagrama completo do módulo (imagem)
![Diagrama Completo](../../docs/fiscal/06-diagrama-completo.svg)

- **Fluxo de emissão** (venda → verificação por item → resolução de regra → SEFAZ): [docs/fiscal/fluxo-emissao.md](../../docs/fiscal/fluxo-emissao.md)
- **Diagrama completo (Mermaid)**: [docs/fiscal/diagrama-completo.md](../../docs/fiscal/diagrama-completo.md)

## Estado atual do código (fase preparação, já implementado)
- produto: origem, gtin, csosn; produtoxml: origem, gtin; tabela produto_fiscal_logs.
- Captura origem/GTIN do XML de compra + log de mudança.
- Cadastro de produto unificado (dashboard/new/edit + modal importação) com seções Produto/Fiscal, selects de Origem e CSOSN (helpers ORIGENS_MERCADORIA e CSOSN_SIMPLES em CollaboratorsBackofficeHelper).

## FATIA 1 — CONCLUÍDA (branch modulo-fiscal, NÃO em produção)
Tudo na branch `modulo-fiscal`, visível só para super_admin (cod_funcionario==1) via SUPER_ADMIN_ONLY_RESOURCES += "fiscal_perfis".

Migrations (rodadas no banco LOCAL apenas):
- 20260925000001_create_tabelas_fiscais: perfil_tributario, operacao_fiscal, regra_fiscal (PKs cod_xxx).
- 20260925000002_add_perfil_tributario_to_produto: produto.cod_perfil_tributario (nullable, sem FK rígida, lock_timeout+disable_ddl_transaction).
- 20260925000003_add_campos_regra_fiscal: regra ganhou soma_total_nota, soma_duplicatas, controla_estoque, cst_ibs_cbs.

Models: PerfilTributario (has_many regras, nested attributes), OperacaoFiscal (tipos saida/entrada), RegraFiscal (belongs_to perfil/operacao/empresa; RegraFiscal.cfop_por_uf(base, uf_emp, uf_cli) => 5/6/7). Produto belongs_to :perfil_tributario optional. Seed db/seeds/fiscal.rb: 6 operacoes basicas.

UI: menu lateral "Fiscal" > Perfis Tributários. CRUD completo (index com contagem de produtos, form perfil+regras com cocoon, show, excluir bloqueado se houver produtos). Select de Perfil no produto (form principal _partial_form + cadastro rápido _produtoNovo_modal). CFOP e CSOSN REMOVIDOS das telas de produto (colunas ficam no banco como legado/fallback); tributação vem do perfil. JS de cadastro rápido (salvarProduto/abrirModal) usa leitura segura e envia cod_perfil_tributario; ComprasController#cadastrar_produto grava cod_perfil_tributario.

Rotas: resources :perfis_tributarios (inflexão irregular "perfil_tributario"/"perfis_tributarios" em config/initializers/inflections.rb).

Decisões desta fase:
- Modelo confirmado (vs MyRP): produto aponta 1 PERFIL; perfil resolve por operacao. NÃO usar de-para por operação no produto (mais simples que MyRP).
- Usuário só usa SEM ST hoje: modelo enxuto, sem campos de ST agora (adicionar depois se precisar).
- Ambiente local: postgresql@16 subido via pg_ctl (brew services estava com erro); pode não subir sozinho após reboot.

Pendente Fatia 1 (opcional): sugestão automática de perfil na importação de XML (ler CST/CSOSN do fornecedor). Próximo grande marco: Fatia 2 — Parte A (fiscal_config + interface FiscalService, NÃO depende de provedor) pode ser feita já; Parte B (adapter concreto) depende de escolher/testar provedor (Focus x Brasil NFe) + certificado A1 válido. Decisão do provedor será por teste em homologação.
