class AddSequenceToCoresCodCor < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TABLE cores ALTER COLUMN cod_cor SET DEFAULT nextval('cor_codigo_seq');
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE cores ALTER COLUMN cod_cor DROP DEFAULT;
    SQL
  end
end