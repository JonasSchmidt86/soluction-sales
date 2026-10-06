class AddEmailXmlToFiscalConfig < ActiveRecord::Migration[7.1]
  # E-mail do contador para onde o pacote de XMLs (saidas) e enviado — manual
  # agora, automatico depois. Um por empresa (fiscal_config e unico por empresa).
  def change
    add_column :fiscal_config, :email_xml, :string, limit: 120,
               comment: "e-mail do contador para envio do pacote de XMLs"
  end
end
