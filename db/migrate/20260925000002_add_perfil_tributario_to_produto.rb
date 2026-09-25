class AddPerfilTributarioToProduto < ActiveRecord::Migration[7.1]
  # Fora da transacao DDL para o lock_timeout valer em cada ALTER.
  disable_ddl_transaction!

  def change
    # ALTER em tabela central e movimentada: desiste em 5s se houver lock
    # preso (ex: transacao "idle in transaction"), em vez de travar a producao.
    # Idempotente (unless column_exists?), pode reexecutar em janela de baixo movimento.
    execute "SET lock_timeout = '5s'"

    # Produto passa a apontar para o Perfil Tributario.
    # nullable e SEM foreign key rigida de proposito: FK exigiria lock mais
    # forte + validacao da tabela inteira. A integridade fica no model
    # (belongs_to optional). Os campos csosn/cfop atuais viram legado/fallback.
    unless column_exists?(:produto, :cod_perfil_tributario)
      add_column :produto, :cod_perfil_tributario, :bigint
    end

    unless index_exists?(:produto, :cod_perfil_tributario, name: "idx_produto_perfil_tributario")
      add_index :produto, :cod_perfil_tributario, name: "idx_produto_perfil_tributario", algorithm: :concurrently
    end
  end
end
