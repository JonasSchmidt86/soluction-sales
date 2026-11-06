# Evento de interacao de um visitante no site publico (catalogo).
# Gravado por SiteAnalytics. Nao contem dados pessoais (sem IP/user-agent);
# o visitor_id e um identificador anonimo de cookie.
class SiteEvent < ApplicationRecord
  VIEW_PORTFOLIO = "view_portfolio".freeze
  VIEW_PRODUTO   = "view_produto".freeze
  CLICK_WHATSAPP = "click_whatsapp".freeze
  BUSCA          = "busca".freeze

  TIPOS = [VIEW_PORTFOLIO, VIEW_PRODUTO, CLICK_WHATSAPP, BUSCA].freeze

  validates :event_type, presence: true, inclusion: { in: TIPOS }
  validates :visitor_id, presence: true

  scope :do_tipo,   ->(tipo) { where(event_type: tipo) }
  scope :no_periodo, ->(inicio, fim) { where(created_at: inicio..fim) }
end
