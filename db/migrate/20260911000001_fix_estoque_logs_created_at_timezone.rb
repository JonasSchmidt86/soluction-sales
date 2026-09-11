class FixEstoqueLogsCreatedAtTimezone < ActiveRecord::Migration[7.1]
  def up
    # Grava created_at sempre no horario de Sao Paulo, independente do timezone
    # da sessao que originou o INSERT (Web em UTC, Java em local, etc.)
    execute <<-SQL
      ALTER TABLE estoque_logs
        ALTER COLUMN created_at SET DEFAULT timezone('America/Sao_Paulo', now());
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE estoque_logs
        ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;
    SQL
  end
end
