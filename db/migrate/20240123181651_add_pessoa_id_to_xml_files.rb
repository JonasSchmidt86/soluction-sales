class AddPessoaIdToXmlFiles < ActiveRecord::Migration[6.1]
  def change
    add_reference :xml_files, :pessoa, foreign_key: {  primary_key: :cod_pessoa, to_table: :pessoa}
  end
end
