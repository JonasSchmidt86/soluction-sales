class AddCobrancaToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Cobranca (fatura + duplicatas) da NF-e — bloco `cobr` do layout SEFAZ, que
  # e o que IMPRIME as parcelas/vencimentos no DANFE para o cliente ver.
  # So e enviado quando ha parcelas informadas E a forma de pagamento e a prazo
  # (diferente de 99 "Outros" e 90 "Sem pagamento"). Guardado como jsonb:
  #   { "fatura": { "numero": "123-F", "valor": 490.0, "desconto": 0.0, "valor_liquido": 490.0 },
  #     "parcelas": [ { "numero": "123-1", "vencimento": "2026-11-20", "valor": 290.0 }, ... ] }
  def change
    add_column :documento_fiscal, :cobranca, :jsonb,
               comment: "Cobranca da NF (fatura + duplicatas/parcelas com vencimento)" unless column_exists?(:documento_fiscal, :cobranca)
  end
end
