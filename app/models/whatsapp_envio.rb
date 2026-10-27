class WhatsappEnvio < ApplicationRecord
  belongs_to :empresa, foreign_key: 'cod_empresa', primary_key: 'cod_empresa', optional: true
  belongs_to :pessoa, foreign_key: 'cod_pessoa', primary_key: 'cod_pessoa', optional: true
  belongs_to :whatsapp_message, optional: true

  validates :cod_empresa, :cod_pessoa, presence: true

  scope :da_empresa,  ->(cod_empresa) { where(cod_empresa: cod_empresa) }
  scope :do_canal,    ->(canal) { where(canal: canal) }
  scope :recentes,    -> { order(enviado_em: :desc) }

  CANAL_ANIVERSARIO = 'aniversario'.freeze
end
