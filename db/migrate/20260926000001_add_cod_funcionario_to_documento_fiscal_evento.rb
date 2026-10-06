class AddCodFuncionarioToDocumentoFiscalEvento < ActiveRecord::Migration[7.1]
  # Guarda QUEM registrou o evento (ex: quem cancelou a NF-e). Junto com
  # justificativa e registrado_em, forma o historico "quem/quando/motivo".
  def change
    unless column_exists?(:documento_fiscal_evento, :cod_funcionario)
      add_column :documento_fiscal_evento, :cod_funcionario, :bigint, comment: "quem registrou o evento"
    end
  end
end
