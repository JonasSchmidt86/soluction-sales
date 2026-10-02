class AddValorTotalToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Guarda o valor total da nota no proprio documento_fiscal, para o dashboard
  # somar valores de forma uniforme (venda, NF avulsa e devolucao de compra) sem
  # depender de cruzamento com venda/compra (a avulsa nao tem origem no banco).
  def change
    unless column_exists?(:documento_fiscal, :valor_total)
      add_column :documento_fiscal, :valor_total, :decimal, precision: 15, scale: 2,
                 comment: "valor total da nota (preenchido na emissao)"
    end
  end
end
