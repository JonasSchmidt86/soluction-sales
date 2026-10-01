class AddIpiRegraFiscal < ActiveRecord::Migration[7.1]
  def change
    # Aba IPI da regra fiscal. No Simples normalmente nao destaca IPI (revenda),
    # mas o campo existe para quem precisar (industria/importacao).
    # Campos conforme payload Brasil NFe: CodSituacaoTributaria, CodEnquadramento, Aliquota.
    add_column :regra_fiscal, :cst_ipi, :string, limit: 3 unless column_exists?(:regra_fiscal, :cst_ipi)
    add_column :regra_fiscal, :cod_enquadramento_ipi, :string, limit: 3 unless column_exists?(:regra_fiscal, :cod_enquadramento_ipi)
    add_column :regra_fiscal, :aliquota_ipi, :decimal, precision: 6, scale: 2 unless column_exists?(:regra_fiscal, :aliquota_ipi)
  end
end
