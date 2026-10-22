class FiscalConfig < ApplicationRecord
  self.table_name = "fiscal_config"
  self.primary_key = "cod_fiscal_config"

  AMBIENTES = %w[homologacao producao].freeze
  REGIMES   = %w[simples presumido real].freeze

  # Credenciais sensiveis do provedor (Brasil NFe) — criptografadas no banco
  # (Active Record Encryption). Token da empresa e UserToken da conta sao UNICOS
  # (o ambiente e decidido na requisicao); o CSC da NFC-e e por ambiente.
  # Nunca trafegam/ficam em texto puro.
  encrypts :brasilnfe_token
  encrypts :brasilnfe_user_token
  encrypts :csc_token_producao
  encrypts :csc_token_homologacao

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

  # --- Credenciais do provedor da empresa ---
  # O adapter usa estes helpers. Fallback para as credentials globais
  # (brasilnfe_token/...) so enquanto a empresa ainda nao tiver o token proprio
  # cadastrado (migracao suave da empresa que ja emite).

  # Token da EMPRESA (transmissao). Unico — o ambiente vai no TipoAmbiente da
  # requisicao, nao e um token por ambiente.
  def brasilnfe_token_efetivo
    brasilnfe_token.presence || credentials_fallback(:brasilnfe_token)
  end

  # UserToken da CONTA (gestao), unico, com fallback nas credentials.
  def brasilnfe_user_token_efetivo
    brasilnfe_user_token.presence || credentials_fallback(:brasilnfe_user_token)
  end

  # Identificador do CSC (idToken) da NFC-e do ambiente atual.
  def csc_id_ambiente
    producao? ? csc_id_producao : csc_id_homologacao
  end

  # Token do CSC da NFC-e do ambiente atual.
  def csc_token_ambiente
    producao? ? csc_token_producao : csc_token_homologacao
  end

  # True quando a empresa ja tem o token proprio cadastrado aqui — isto e, nao
  # depende mais do fallback global das credentials.
  def credenciais_proprias?
    brasilnfe_token.present?
  end

  private

  def credentials_fallback(chave)
    Rails.application.credentials.public_send(chave)
  rescue
    nil
  end

  public

  # Retorna (e reserva) o proximo numero da serie informada, incrementando.
  # modelo: 55 (NF-e) ou 65 (NFC-e). Uso real virá na emissão (Parte B/3).
  def proximo_numero!(modelo)
    campo = modelo.to_i == 65 ? :proximo_numero_nfce : :proximo_numero_nfe
    numero = public_send(campo)
    update_column(campo, numero.to_i + 1)
    numero
  end
end
