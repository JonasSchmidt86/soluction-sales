class AddTipoToPerfilTributario < ActiveRecord::Migration[7.1]
  # Classifica o perfil tributario como de SAIDA (venda/devolucao de compra) ou
  # ENTRADA (devolucao de venda/compra), para filtrar os perfis conforme o
  # contexto (ex.: na devolucao de compra so aparecem perfis de saida).
  def change
    unless column_exists?(:perfil_tributario, :tipo)
      add_column :perfil_tributario, :tipo, :string, limit: 10, default: "saida", null: false,
                 comment: "saida / entrada"
    end
  end
end
