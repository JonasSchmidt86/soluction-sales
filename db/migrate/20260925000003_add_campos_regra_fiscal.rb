class AddCamposRegraFiscal < ActiveRecord::Migration[7.1]
  def change
    # Campos essenciais observados no MyRP, adaptados ao caso (Simples, sem ST).
    # soma_total_nota: o valor do item entra no total da NF-e?
    # soma_duplicatas: o valor do item soma no total das duplicatas (financeiro)?
    # controla_estoque: como afeta estoque (nao_controla / proprio)
    # cst_ibs_cbs: CST de IBS/CBS (reforma; complementa cclasstrib)
    add_column :regra_fiscal, :soma_total_nota, :boolean, default: true, null: false unless column_exists?(:regra_fiscal, :soma_total_nota)
    add_column :regra_fiscal, :soma_duplicatas, :boolean, default: true, null: false unless column_exists?(:regra_fiscal, :soma_duplicatas)
    add_column :regra_fiscal, :controla_estoque, :string, limit: 20, default: "proprio" unless column_exists?(:regra_fiscal, :controla_estoque)
    add_column :regra_fiscal, :cst_ibs_cbs, :string, limit: 10 unless column_exists?(:regra_fiscal, :cst_ibs_cbs)
  end
end
