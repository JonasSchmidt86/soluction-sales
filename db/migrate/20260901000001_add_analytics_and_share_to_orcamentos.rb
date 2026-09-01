# frozen_string_literal: true

# Colunas de analytics e compartilhamento do orçamento que existiam no banco
# local mas nunca tiveram migration versionada. Esta migration as adiciona de
# forma idempotente para alinhar produção e local sem quebrar quem já as tem.
class AddAnalyticsAndShareToOrcamentos < ActiveRecord::Migration[7.1]
  COLUNAS = {
    views_count:           { type: :integer,  options: { default: 0, null: false } },
    total_view_seconds:    { type: :integer,  options: { default: 0, null: false } },
    first_viewed_at:       { type: :datetime, options: {} },
    last_viewed_at:        { type: :datetime, options: {} },
    share_token:           { type: :string,   options: {} },
    share_failed_attempts: { type: :integer,  options: { default: 0, null: false } },
    share_blocked_until:   { type: :datetime, options: {} }
  }.freeze

  def up
    COLUNAS.each do |nome, config|
      next if column_exists?(:orcamentos, nome)

      add_column :orcamentos, nome, config[:type], **config[:options]
    end

    add_index :orcamentos, :share_token, unique: true unless index_exists?(:orcamentos, :share_token)
  end

  def down
    remove_index :orcamentos, :share_token if index_exists?(:orcamentos, :share_token)

    COLUNAS.each_key do |nome|
      remove_column :orcamentos, nome if column_exists?(:orcamentos, nome)
    end
  end
end
