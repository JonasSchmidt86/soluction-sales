class AmpliarChaveAcessoNotaRecebida < ActiveRecord::Migration[7.1]
  # NF-e/NFC-e tem chave de 44 digitos, mas NFS-e e documentos de servico/telecom
  # (modelo 10) que a distribuicao DF-e traz usam chaves MAIORES (ex. 50 digitos).
  # A coluna estava limitada a 44 (value too long ao registrar essas notas).
  # Amplia para 60 para comportar todos os tipos.
  def up
    change_column :nota_recebida, :chave_acesso, :string, limit: 60
  end

  def down
    change_column :nota_recebida, :chave_acesso, :string, limit: 44
  end
end
