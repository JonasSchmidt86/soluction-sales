# Valores da nota (NF avulsa): outras despesas (vOutro), desconto (vDesc) e
# frete (vFrete). Entram no total da nota e sao rateados por item no builder.
# Diferente do bloco "transporte" (dados logisticos sem valor): aqui e so o
# VALOR monetario de cada rubrica. Default 0 (nota sem ajuste = nada muda).
class AddValoresToDocumentoFiscal < ActiveRecord::Migration[7.0]
  def change
    add_column :documento_fiscal, :outras_despesas, :decimal, precision: 15, scale: 2, default: 0,
               comment: "Valor de outras despesas acessorias da nota (vOutro)"
    add_column :documento_fiscal, :desconto, :decimal, precision: 15, scale: 2, default: 0,
               comment: "Valor de desconto da nota (vDesc)"
    add_column :documento_fiscal, :frete, :decimal, precision: 15, scale: 2, default: 0,
               comment: "Valor do frete da nota (vFrete)"
  end
end
