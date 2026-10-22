class AddNumeronfToXmlFiles < ActiveRecord::Migration[7.1]
  # Numero da NF (nNF) e CHAVE de acesso (44 digitos) do XML, gravados no
  # proprio xml_file para: (a) filtrar a lista por numero sem reparsear o XML;
  # (b) obter a chave da devolucao direto do registro (sem reler o XML).
  # Preenchidos no create (que ja le o XML) e por backfill dos existentes
  # (rake xml_files:backfill_numeronf).
  def change
    unless column_exists?(:xml_files, :numeronf)
      add_column :xml_files, :numeronf, :string, limit: 20,
                 comment: "Numero da NF (nNF) do XML, para busca na listagem"
      add_index :xml_files, :numeronf
    end
    unless column_exists?(:xml_files, :chave)
      add_column :xml_files, :chave, :string, limit: 44,
                 comment: "Chave de acesso (44 digitos) da NF-e do XML"
      add_index :xml_files, :chave
    end
  end
end
