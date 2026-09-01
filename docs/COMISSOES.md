# Sistema de Comissões

Documentação de como o módulo de comissões funciona: conceitos, fluxo, onde
está cada arquivo e as regras de negócio. Serve como referência para quem for
dar manutenção ou continuar o desenvolvimento.

Última revisão: 01/09/2026

---

## Visão geral

O módulo calcula a comissão dos vendedores com base nas vendas de um período,
usando uma tabela de faixas progressivas (quanto mais vende, maior o percentual
sobre a parte que ultrapassa cada faixa). O fluxo típico é:

1. Cadastra-se uma **regra de comissão** (com suas faixas).
2. Atribui-se a regra a um vendedor a partir de uma data (**atribuição**).
3. Na tela de apurações, o admin vê uma **simulação em tempo real** por mês.
4. Quando o mês fecha, gera-se a **apuração** (period), que congela os valores.
5. A apuração é **finalizada** e depois **marcada como paga**.
6. Se uma venda for cancelada depois de paga, o sistema cria um **ajuste**
   (débito) que entra na próxima apuração.

---

## Conceitos e modelos

Todos os modelos ficam em `app/models/`.

| Modelo | Tabela | O que representa |
|---|---|---|
| `CommissionRule` | `commission_rules` | Regra de comissão (nome, empresa, ativa/inativa). |
| `CommissionTier` | `commission_tiers` | Cada faixa da regra: valor mínimo, máximo e percentual. |
| `CommissionAssignment` | `commission_assignments` | Liga uma regra a um vendedor com vigência (`start_date`/`end_date`). |
| `CommissionPeriod` | `commission_periods` | Apuração de um vendedor num intervalo. Guarda os totais congelados. |
| `CommissionPeriodSale` | `commission_period_sales` | Snapshot de cada venda que entrou na apuração, com sua comissão individual. |
| `CommissionAdjustment` | `commission_adjustments` | Ajustes (débito/crédito) aplicados numa apuração futura. |
| `CommissionPayment` | `commission_payments` | Registro do pagamento efetuado de uma apuração. |

### Status de uma apuração (`CommissionPeriod#status`)

- `open` — criada e/ou calculada, ainda editável.
- `finalized` — valores congelados; snapshot da regra e faixas gravado; ajustes pendentes aplicados.
- `paid` — pagamento registrado.

Transições: `open → finalized → paid`. Um admin geral (super admin) pode
**reabrir** (`reopen`), voltando para `open` e revertendo os ajustes que tinham
sido aplicados naquele período.

---

## Cálculo progressivo

Arquivo: `app/services/commission_calculator_service.rb`

Pontos importantes:

- Usa **`BigDecimal`** em todos os cálculos financeiros (nunca float).
- A comissão é **progressiva**: cada faixa incide apenas sobre a parte do total
  de vendas que cai dentro daquela faixa (não aplica a última faixa sobre tudo).
- Vendas são processadas em ordem: `datavenda ASC, cod_venda ASC`.
- Cada venda recebe seu próprio `commission_amount`; a soma das comissões
  individuais é igual ao total. Um ajuste de centavo é aplicado na última venda
  para garantir a soma exata.
- Arredondamento: `HALF_UP`, 2 casas decimais.

Vendas consideradas válidas (ver `CommissionPeriod#fetch_sales` e o service de
simulação): não canceladas (`cancelada` false/nil) e com `tipo` diferente de
`'T'`, dentro do intervalo de datas.

---

## Serviços (lógica de negócio)

Ficam em `app/services/`.

### `CommissionSimulationService`
Simula comissões **on-the-fly, sem gravar nada no banco**. Alimenta a tela de
apurações com a estimativa do mês.

- `simulate_all(cod_empresa:, start_date:, end_date:)` — simula todos os
  vendedores com atribuição vigente na empresa.
- `simulate_one(cod_funcionario:, cod_empresa:, start_date:, end_date:)` —
  simula um vendedor (usado na visão do próprio vendedor).

Regras da simulação:
- Só entra quem tem **atribuição vigente** no período.
- Vendedor **sem vendas** no período não aparece.
- Vendedor que **já tem apuração gerada** sobreposta ao período **não aparece**
  (a estimativa some assim que a comissão é apurada). A checagem é por
  sobreposição de datas com qualquer `CommissionPeriod` do vendedor.

### `CommissionPeriodService`
Cuida do ciclo de vida da apuração (recebe um `CommissionPeriod`):

- `calculate` — calcula/recalcula (só em apuração `open`). Grava os snapshots de
  vendas em `commission_period_sales` e atualiza os totais.
- `finalize(finalized_by:)` — congela valores, grava snapshot da regra/faixas e
  **aplica os ajustes pendentes** do vendedor.
- `mark_as_paid(paid_by:)` — só em apuração `finalized`; cria o `CommissionPayment`.
- `reopen(reopened_by:, reason:)` — só admin geral; volta para `open` e reverte
  os ajustes aplicados. Motivo é obrigatório.

Validações importantes:
- Bloqueia se houver **mais de uma regra vigente** no período (`MultipleRulesError`).
- Bloqueia se **nenhuma regra** estiver atribuída no período (`NoRuleError`).

### `CommissionAdjustmentService`
Gerencia os ajustes:

- `detect_cancelled_sales(...)` / `detect_cancelled_sales_for_empresa(...)` —
  varre apurações finalizadas/pagas e cria **ajuste de débito** para vendas que
  foram canceladas depois de a comissão ter sido apurada. Um índice único
  `[cod_venda, commission_period_id, adjustment_type]` evita duplicidade.
- `create_manual(...)` — cria ajuste manual (débito ou crédito).
- `cancel(adjustment, cancelled_by:)` — cancela um ajuste pendente.
- `pending_summary(...)` — resumo de débitos/créditos pendentes.

Ajustes pendentes são incorporados quando a **próxima apuração é finalizada**
(`net_commission = comissão − (débitos − créditos)`).

---

## Controllers e telas

Ficam em `app/controllers/collaborators_backoffice/` e as views em
`app/views/collaborators_backoffice/`.

| Controller | Responsabilidade |
|---|---|
| `commission_rules_controller.rb` | CRUD das regras e faixas. |
| `commission_assignments_controller.rb` | Atribuir/encerrar regras por vendedor. |
| `commission_periods_controller.rb` | Apurações: simulação, criar, calcular, finalizar, pagar, reabrir. |
| `commission_adjustments_controller.rb` | Ajustes (manuais e detecção de cancelados). |

### Tela de apurações (`commission_periods#index`)

É a tela principal do dia a dia. Comportamento:

- **Seletor de mês** sempre visível no topo. A simulação vai sempre do **dia 01
  ao último dia** do mês escolhido. Aceita `?mes=YYYY-MM`; sem parâmetro, usa o
  mês atual. Há atalhos "Mês passado" e "Mês atual".
- **Estimativa do período**: lista os vendedores simulados (quem ainda não foi
  apurado e teve vendas). Botão **Apurar** cria a apuração já calculada do mês
  inteiro (`quick_create`).
- **Apurações Registradas**: lista as apurações já geradas cujo período se
  sobrepõe ao mês selecionado.

Admin (nível de permissão 1) vê todos os vendedores; vendedor comum vê apenas a
própria simulação/apuração.

---

## Permissões

- **Admin** (`funcionario.permissao.nivel == 1`): gerencia regras, atribuições e
  apurações; calcula, finaliza e marca como pago.
- **Super admin** (`funcionario.super_admin?`): além do acima, pode **reabrir**
  apurações finalizadas/pagas.
- **Vendedor comum**: vê apenas suas próprias comissões (simulação e apurações),
  sem ações administrativas.

---

## Fluxo passo a passo (operação normal)

1. **Configurar** (uma vez): criar a regra com as faixas e atribuir ao vendedor.
2. **Durante o mês**: abrir Apurações de Comissão para acompanhar a estimativa.
3. **Fechamento** (ex.: início do mês seguinte): selecionar o mês (ou "Mês
   passado") → conferir a estimativa → clicar **Apurar** no vendedor. A linha
   sai da simulação e a apuração aparece em "Apurações Registradas".
4. **Finalizar** a apuração (congela valores e aplica ajustes pendentes).
5. **Marcar como paga** após o pagamento.
6. **Cancelamento posterior de venda**: rodar a detecção de cancelados para
   gerar o débito, que entra na próxima apuração finalizada.

---

## Observações para manutenção

- Todo cálculo financeiro usa `BigDecimal`. Manter esse padrão em qualquer
  alteração para evitar erros de arredondamento.
- Os serviços **não alteram** as tabelas existentes de `venda`, `funcionario` e
  `empresa` — apenas leem. Os dados de comissão vivem nas tabelas próprias.
- Ao finalizar uma apuração, a regra e as faixas são gravadas em snapshot
  (`rule_snapshot`, `tiers_breakdown`), então mudanças posteriores na regra não
  afetam apurações já finalizadas.
- Migrations do módulo: `db/migrate/20260811000001..07_*commission*`.
