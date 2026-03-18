class AddAtivoToLancamentosdiversos < ActiveRecord::Migration[7.1]
  def change
    add_column :lancamentosdiversos, :ativo, :boolean, default: true, null: false
  end
end
