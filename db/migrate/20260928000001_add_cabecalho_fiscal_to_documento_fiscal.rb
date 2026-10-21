class AddCabecalhoFiscalToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Campos de cabecalho da nota (avulsa/venda) que o editor passou a oferecer:
  #   - info_adicional        -> Observacao (infCpl: aparece no DANFE)
  #   - info_adicional_fisco  -> ObservacaoFisco (infAdFisco: observacao ao fisco)
  #   - forma_pagamento       -> tPag (01 dinheiro, 03 credito, 17 PIX, 99 outros...)
  #   - descricao_pagamento   -> xPag (obrigatorio quando tPag=99, rejeicao 441)
  #   - chave_referenciada    -> NFReferencia (chave 44 digitos da NF de compra
  #                              referenciada em devolucao/outra saida)
  # Persistidos para sobreviver ao salvar/editar o rascunho (padrao do editor).
  def change
    add_column :documento_fiscal, :info_adicional, :text,
               comment: "Observacao da NF (infCpl, aparece no DANFE)" unless column_exists?(:documento_fiscal, :info_adicional)
    add_column :documento_fiscal, :info_adicional_fisco, :text,
               comment: "Observacao ao fisco da NF (infAdFisco)" unless column_exists?(:documento_fiscal, :info_adicional_fisco)
    add_column :documento_fiscal, :forma_pagamento, :string, limit: 2,
               comment: "Forma de pagamento (tPag SEFAZ): 01,03,04,15,17,90,99..." unless column_exists?(:documento_fiscal, :forma_pagamento)
    add_column :documento_fiscal, :descricao_pagamento, :string, limit: 60,
               comment: "Descricao do pagamento (xPag), obrigatoria quando tPag=99" unless column_exists?(:documento_fiscal, :descricao_pagamento)
    add_column :documento_fiscal, :chave_referenciada, :string, limit: 44,
               comment: "Chave de acesso da NF referenciada (NFReferencia)" unless column_exists?(:documento_fiscal, :chave_referenciada)
  end
end
