class AddCodCompraToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Vincula o documento fiscal a uma COMPRA (usado na NF-e de DEVOLUÇÃO de
  # compra). Até aqui o documento_fiscal só referenciava venda (cod_venda).
  # Nullable: a maioria dos documentos (venda/avulsa) não tem compra.
  def change
    unless column_exists?(:documento_fiscal, :cod_compra)
      add_column :documento_fiscal, :cod_compra, :bigint,
                 comment: "compra de origem (NF de devolução de compra)"
      add_index  :documento_fiscal, :cod_compra, name: "idx_documento_fiscal_compra"
    end
  end
end
