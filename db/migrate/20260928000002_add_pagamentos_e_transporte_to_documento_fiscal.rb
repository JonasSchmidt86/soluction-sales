class AddPagamentosETransporteToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Pagamento vira LISTA (como no painel Brasil NFe): varias formas por nota,
  # cada uma com forma (tPag) e valor pago. Guardado como jsonb (lista variavel),
  # em vez de varias colunas. As colunas forma_pagamento/descricao_pagamento da
  # migration anterior (20260928000001) ficam como LEGADO (nao usadas pelo editor
  # novo); nao sao removidas por ja estarem versionadas.
  #   pagamentos: [{ "forma" => "01", "valor" => 100.0, "descricao" => nil }, ...]
  #
  # Transporte: dados de frete/transportadora/volumes como jsonb (estrutura
  # montada ja no form; o envio ao provedor sera ligado na etapa de transporte).
  #   transporte: { "modalidade_frete" => "0", "transportadora" => {...},
  #                 "volumes" => {...} }
  def change
    add_column :documento_fiscal, :pagamentos, :jsonb,
               comment: "Lista de pagamentos da nota [{forma,valor,descricao}] (tPag/VlPago)" unless column_exists?(:documento_fiscal, :pagamentos)
    add_column :documento_fiscal, :transporte, :jsonb,
               comment: "Dados de transporte/frete (modalidade, transportadora, volumes)" unless column_exists?(:documento_fiscal, :transporte)
  end
end
