class AddRascunhoFieldsToDocumentoFiscal < ActiveRecord::Migration[7.1]
  # Campos usados pela NOTA EM ELABORACAO (rascunho) para reconstruir o form na
  # edicao: o destinatario e a operacao escolhidos. So fazem sentido enquanto
  # rascunho; na emissao o destinatario/operacao viram parte do payload/XML.
  def change
    add_column :documento_fiscal, :cod_pessoa_rascunho, :bigint,
               comment: "destinatario escolhido (rascunho da nota em elaboracao)" unless column_exists?(:documento_fiscal, :cod_pessoa_rascunho)
    add_column :documento_fiscal, :cod_operacao_fiscal_rascunho, :bigint,
               comment: "operacao fiscal escolhida (rascunho da nota em elaboracao)" unless column_exists?(:documento_fiscal, :cod_operacao_fiscal_rascunho)
  end
end
