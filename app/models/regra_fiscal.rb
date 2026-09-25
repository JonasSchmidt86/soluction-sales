class RegraFiscal < ApplicationRecord
  self.table_name = "regra_fiscal"
  self.primary_key = "cod_regra_fiscal"

  CURINGA = "*".freeze

  belongs_to :perfil, class_name: "PerfilTributario",
             foreign_key: "cod_perfil_tributario", primary_key: "cod_perfil_tributario",
             inverse_of: :regras
  belongs_to :operacao, class_name: "OperacaoFiscal",
             foreign_key: "cod_operacao_fiscal", primary_key: "cod_operacao_fiscal",
             inverse_of: :regras
  belongs_to :empresa, class_name: "Empresa",
             foreign_key: "cod_empresa", primary_key: "cod_empresa"

  validates :cfop_base, presence: true
  validates :uf_destino, presence: true
  validates :tipo_cliente, presence: true

  scope :ativos, -> { where(ativo: true) }

  # Resolve o CFOP completo comparando UF da empresa emitente x UF do cliente.
  # 5 = dentro do estado, 6 = fora do estado, 7 = exterior.
  # cfop_base tem 3 digitos (ex "102") -> 5102 / 6102 / 7102.
  def self.cfop_por_uf(cfop_base, uf_empresa, uf_cliente)
    base = cfop_base.to_s.strip
    return nil if base.blank?

    prefixo =
      if uf_cliente.to_s.strip.upcase == "EX" # exterior
        "7"
      elsif uf_empresa.to_s.strip.upcase == uf_cliente.to_s.strip.upcase
        "5"
      else
        "6"
      end
    "#{prefixo}#{base}"
  end

  # Instancia: usa o cfop_base desta regra.
  def cfop_resolvido(uf_empresa, uf_cliente)
    self.class.cfop_por_uf(cfop_base, uf_empresa, uf_cliente)
  end
end
