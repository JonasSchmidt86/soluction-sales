# frozen_string_literal: true

class AddLinkOptionsToOrcamentos < ActiveRecord::Migration[7.1]
  def change
    # Link público nasce ABERTO (sem senha) por padrão.
    add_column :orcamentos, :link_protegido, :boolean, default: false, null: false

    # Senha customizada de 4 dígitos definida pelo vendedor.
    # Quando nula, o fallback é o final do telefone do cliente.
    add_column :orcamentos, :senha_publica_customizada, :string, limit: 4

    # Data/hora de expiração explícita do link.
    # Quando nula, mantém o comportamento antigo (data_validade / status).
    add_column :orcamentos, :link_expira_em, :datetime
  end
end
