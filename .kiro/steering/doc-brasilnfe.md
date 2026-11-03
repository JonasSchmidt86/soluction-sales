---
inclusion: auto
name: Documentação Brasil NFe (local)
description: Como e onde consultar a documentação do provedor fiscal Brasil NFe. Ative ao trabalhar com emissão/cancelamento de NF-e/NFC-e, adapter fiscal, payload de notas, impostos (ICMS/IPI/PIS/COFINS/CSOSN), CFOP, devoluções ou qualquer tema do módulo fiscal.
---

# Documentação do provedor fiscal (Brasil NFe)

Antes de mexer no adapter fiscal, no payload de notas ou em qualquer regra de
emissão/eventos, **consulte sempre a documentação LOCAL**, não o site online.

- Local: `docs/brasilnfe/`
  - `README.md` — fatos-chave já extraídos.
  - `EnviarNotaFiscal-referencia.md` — payload de emissão.
  - `nf-e-nfce.md`, `eventos.md`, `consultas.md`, `empresas.md` — por tema.
  - PDFs originais da API 2.0 na mesma pasta.
- **Não** tente buscar/fazer fetch no site da Brasil NFe: a doc online é
  renderizada por JS e não retorna conteúdo útil — por isso os PDFs/resumos
  foram salvos localmente.

Para o contexto completo de arquitetura e decisões do módulo fiscal, referencie
a steering `#modulo-fiscal` (inclusão manual).
