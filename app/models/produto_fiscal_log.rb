class ProdutoFiscalLog < ApplicationRecord
  self.table_name = "produto_fiscal_logs"

  belongs_to :produto, class_name: "Produto", foreign_key: "cod_produto", optional: true
  belongs_to :pessoa,  class_name: "Pessoa",  foreign_key: "cod_pessoa",  optional: true

  # Registra a mudanca de um campo fiscal do produto, quando o novo valor
  # difere do atual. Nao lanca excecao: log nunca deve quebrar a importacao.
  def self.registrar(produto:, campo:, valor_novo:, empresa_id: nil, pessoa_id: nil, numeronf: nil)
    return if produto.blank? || campo.blank?

    valor_novo = valor_novo.to_s.strip
    valor_antigo = produto.public_send(campo).to_s.strip

    return if valor_novo.blank? || valor_novo == valor_antigo

    create!(
      cod_produto: produto.cod_produto,
      cod_empresa: empresa_id,
      cod_pessoa: pessoa_id,
      numeronf: numeronf.to_s.presence,
      campo: campo.to_s,
      valor_antigo: valor_antigo.presence,
      valor_novo: valor_novo,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.error "Falha ao registrar ProdutoFiscalLog (produto #{produto&.cod_produto}, campo #{campo}): #{e.message}"
    nil
  end
end
