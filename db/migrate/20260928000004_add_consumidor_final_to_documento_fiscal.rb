class AddConsumidorFinalToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Escolha manual de "Operacao com consumidor final?" na nota avulsa (indFinal
  # do layout SEFAZ). "sim"/"nao"/nil. nil = automatico (o builder infere pelo
  # PF/PJ). Resolve a rejeicao 696 (destinatario PJ NAO contribuinte exige
  # indFinal=1), deixando o colaborador informar explicitamente.
  def change
    add_column :documento_fiscal, :consumidor_final, :string, limit: 3,
               comment: "Operacao com consumidor final (indFinal): sim/nao/nil(auto)" unless column_exists?(:documento_fiscal, :consumidor_final)
  end
end
