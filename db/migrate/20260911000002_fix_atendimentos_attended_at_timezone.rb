class FixAtendimentosAttendedAtTimezone < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TABLE atendimentos
        ALTER COLUMN attended_at SET DEFAULT timezone('America/Sao_Paulo', now());
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE atendimentos
        ALTER COLUMN attended_at SET DEFAULT CURRENT_TIMESTAMP;
    SQL
  end
end
