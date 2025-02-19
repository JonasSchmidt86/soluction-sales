class AddIdToCaixa < ActiveRecord::Migration[5.2]
  
  def change
  
    unless column_exists?(:caixa, :id)
      # Adiciona a coluna 'id' temporariamente como integer
      add_column :caixa, :id, :bigint;

      # Preenche os valores para a nova coluna 'id' ordenados por 'dataabertura' e 'cod_empresa'
      execute <<-SQL
        WITH caixa_ordered AS (
          SELECT ctid AS row_id, ROW_NUMBER() OVER (ORDER BY dataabertura ASC, cod_empresa ASC) AS new_id
          FROM caixa
        )
        UPDATE caixa
           SET id = caixa_ordered.new_id
          FROM caixa_ordered
         WHERE caixa.ctid = caixa_ordered.row_id;

         
         CREATE SEQUENCE caixa_id_seq
          OWNED BY caixa.id;

          ALTER TABLE caixa
          ALTER COLUMN id SET DEFAULT nextval('caixa_id_seq');

          SELECT setval('caixa_id_seq', COALESCE(MAX(id), 1)) FROM caixa;
          
      SQL

      # Configura a coluna como chave primária e converte para serial
      execute <<-SQL
        ALTER TABLE caixa
        ALTER COLUMN id SET NOT NULL;
        -- ADD CONSTRAINT caixa_pkey PRIMARY KEY (id);
      SQL
    end
  end
end
