# Proteção contra abuso dos endpoints que disparam e-mail (recuperação de senha).
# Sem isso, um atacante poderia marteler o formulário público de "esqueci senha"
# e esgotar a cota de envio do provedor (Gmail) ou inundar a caixa de um usuário.
class Rack::Attack
  # Store dedicado em memória para os contadores de rate limit.
  # Suficiente para um único processo/servidor. Se um dia migrar para múltiplos
  # servidores ou vários workers, troque por um store compartilhado (ex.: Redis).
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Caminho do fluxo público "esqueci minha senha" do Devise (collaborators).
  RESET_PATH = "/collaborators/password".freeze

  # Limite por IP: no máximo 5 pedidos de recuperação a cada 60 segundos.
  throttle("password-reset/ip", limit: 5, period: 60.seconds) do |req|
    if req.post? && req.path == RESET_PATH
      req.ip
    end
  end

  # Limite por e-mail alvo: no máximo 3 pedidos para o mesmo e-mail a cada 15 min.
  # Evita que alguém fique inundando a caixa de um colaborador específico.
  throttle("password-reset/email", limit: 3, period: 15.minutes) do |req|
    if req.post? && req.path == RESET_PATH
      email = req.params.dig("collaborator", "email").to_s.downcase.strip
      email.presence
    end
  end

  # Botão de reset acionado pelo admin no backoffice (exige login, risco menor,
  # mas limitamos por IP como salvaguarda extra).
  throttle("admin-reset/ip", limit: 10, period: 60.seconds) do |req|
    if req.post? && req.path.match?(%r{\A/collaborators_backoffice/collaborators/\d+/reset_password\z})
      req.ip
    end
  end

  # Resposta quando o limite é excedido: 429 com mensagem amigável.
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/html; charset=utf-8" },
      ["<h1>Muitas tentativas</h1><p>Você fez muitos pedidos de redefinição de senha em pouco tempo. Aguarde alguns minutos e tente novamente.</p>"]
    ]
  end
end
