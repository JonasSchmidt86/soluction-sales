class AddCompraRefToXmlFiles < ActiveRecord::Migration[6.1]
  def change
    add_reference :xml_files, :compra, foreign_key: {  primary_key: :cod_compra, to_table: :compra}
  end
end
