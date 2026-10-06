class AddAliquotasRegraFiscal < ActiveRecord::Migration[7.1]
  def change
    # Aliquotas para as abas PIS/COFINS/FCP da tela de regra fiscal.
    # No Simples geralmente ficam zeradas (CST nao-tributavel), mas o campo
    # existe para regimes/casos que precisem destacar.
    add_column :regra_fiscal, :aliquota_pis, :decimal, precision: 6, scale: 2 unless column_exists?(:regra_fiscal, :aliquota_pis)
    add_column :regra_fiscal, :aliquota_cofins, :decimal, precision: 6, scale: 2 unless column_exists?(:regra_fiscal, :aliquota_cofins)
    add_column :regra_fiscal, :aliquota_fcp, :decimal, precision: 6, scale: 2 unless column_exists?(:regra_fiscal, :aliquota_fcp)
  end
end
