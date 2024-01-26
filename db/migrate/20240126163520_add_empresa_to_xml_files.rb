class AddEmpresaToXmlFiles < ActiveRecord::Migration[6.1]
  def change
    add_reference :xml_files, :empresa, foreign_key: {  primary_key: :cod_empresa, to_table: :empresa}
  end
end
