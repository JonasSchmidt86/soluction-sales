class AddIdToLancamentoscaixa < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:lancamentoscaixa, :caixa_id)
      add_column :lancamentoscaixa, :caixa_id, :bigint

      # Atualiza caixa_id em lancamentoscaixa com base em caixa
      execute <<-SQL
        UPDATE lancamentoscaixa AS l
        SET caixa_id = x.id
        FROM caixa AS x
        WHERE l.dataabertura = x.dataabertura
          AND l.cod_empresa = x.cod_empresa;
      SQL

      # Adiciona índice para melhorar desempenho
      # add_index :caixa, [:dataabertura, :cod_empresa]
      # add_index :lancamentoscaixa, [:dataabertura, :cod_empresa]

      # Adiciona chave estrangeira
      # add_foreign_key :lancamentoscaixa, :caixa, column: :caixa_id
    end
  end
end
