class FiscalConfig < ApplicationRecord
  self.table_name = "fiscal_config"
  self.primary_key = "cod_fiscal_config"

  AMBIENTES = %w[homologacao producao].freeze
  REGIMES   = %w[simples presumido real].freeze

  belongs_to :empresa, class_name: "Empresa",
             foreign_key: "cod_empresa", primary_key: "cod_empresa"

  validates :cod_empresa, presence: true, uniqueness: true
  validates :ambiente, inclusion: { in: AMBIENTES }
  validates :regime_tributario, inclusion: { in: REGIMES }
  validates :serie_nfe, :serie_nfce,
            :proximo_numero_nfe, :proximo_numero_nfce,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def producao?
    ambiente == "producao"
  end

  def homologacao?
    ambiente == "homologacao"
  end

  # Retorna (e reserva) o proximo numero da serie informada, incrementando.
  # modelo: 55 (NF-e) ou 65 (NFC-e). Uso real virá na emissão (Parte B/3).
  def proximo_numero!(modelo)
    campo = modelo.to_i == 65 ? :proximo_numero_nfce : :proximo_numero_nfe
    numero = public_send(campo)
    update_column(campo, numero.to_i + 1)
    numero
  end
end
