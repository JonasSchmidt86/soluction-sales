# Endpoints ANONIMOS de analytics do catalogo publico, chamados pelo navegador via
# fetch / navigator.sendBeacon (ver .kiro/specs/analytics-portfolio):
#
#   POST /a/whatsapp  -> registra um clique em contato do WhatsApp
#   POST /a/tempo     -> soma o tempo de permanencia ao evento view_produto da visita
#
# Sempre responde 204, sem corpo: o navegador nao precisa (e nao deve) saber se o
# evento foi aceito, e uma falha aqui nunca pode atrapalhar o cliente.
#
# Herda direto de ActionController::Base (sem os filtros de login/SET LOCAL do
# ApplicationController) para ficar leve. A protecao CSRF fica desligada de proposito:
# sendBeacon nao envia cabecalhos, o token pode expirar com a pagina aberta (evento
# perdido em silencio) e estes endpoints so gravam um evento anonimo, que qualquer
# um poderia enviar direto sem cookie. A autorizacao real do /a/tempo e o cookie
# assinado do visitante.
class SiteEventsController < ActionController::Base
  skip_forgery_protection

  # Tempo maximo por evento (e por envio): acima disso e quase certamente uma aba
  # esquecida aberta e distorceria a media de permanencia por produto.
  MAX_SEGUNDOS = 3600

  rescue_from(StandardError) do |e|
    logger.error "[SiteEvents] #{e.class}: #{e.message}"
    head :no_content
  end

  # params: cod_produto (opcional; descartado se invalido ou inexistente)
  def whatsapp
    bruto = params[:cod_produto]
    cod   = nil

    if bruto.present?
      cod = Integer(bruto.to_s, 10, exception: false)
      return head(:no_content) if cod.nil? || !Produto.exists?(cod_produto: cod)
    end

    SiteAnalytics.track(event_type: SiteEvent::CLICK_WHATSAPP, request: request,
                        cookies: cookies, cod_produto: cod)
    head :no_content
  end

  # params: evento_id (id do view_produto da visita), segundos (tempo desde o ultimo envio)
  # So aceita se o evento pertencer ao visitante do cookie assinado.
  def tempo
    visitante = SiteAnalytics.visitor_atual(cookies)
    evento_id = Integer(params[:evento_id].to_s, 10, exception: false)
    segundos  = Float(params[:segundos].to_s, exception: false)&.round

    if visitante && evento_id && segundos&.between?(1, MAX_SEGUNDOS)
      SiteEvent.where(id: evento_id, event_type: SiteEvent::VIEW_PRODUTO, visitor_id: visitante)
               .update_all(["duracao_seg = LEAST(COALESCE(duracao_seg, 0) + ?, ?)",
                            segundos, MAX_SEGUNDOS])
    end

    head :no_content
  end
end
