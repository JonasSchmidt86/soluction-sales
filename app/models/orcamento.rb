class Orcamento < ApplicationRecord
  self.table_name = "orcamentos"
  self.primary_key = "cod_orcamento"

  TEMAS = %w[premium classico executivo].freeze

  # Opções de validade do link público oferecidas ao vendedor.
  # O valor `orcamento` mantém o comportamento antigo (usa data_validade/status).
  VALIDADES_LINK = {
    "24h"       => 24.hours,
    "48h"       => 48.hours,
    "7d"        => 7.days,
    "orcamento" => nil
  }.freeze

  attr_accessor :nome_pessoa

  has_many :itens_orcamentos, class_name: 'ItemOrcamento', foreign_key: 'cod_orcamento', 
           inverse_of: :orcamento, dependent: :destroy, autosave: true
  accepts_nested_attributes_for :itens_orcamentos, allow_destroy: true, 
    reject_if: proc { |attr| attr['cod_produto'].blank? && attr['quantidade'].to_f <= 0 }

  belongs_to :pessoa, class_name: 'Pessoa', foreign_key: 'cod_pessoa'
  belongs_to :funcionario, class_name: 'Funcionario', foreign_key: 'cod_funcionario'
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'cod_empresa'
  belongs_to :venda, class_name: 'Venda', foreign_key: 'cod_venda', optional: true

  validates :pessoa, :funcionario, :empresa, :data_orcamento, presence: true
  validates :status, inclusion: { in: %w[pendente aprovado rejeitado convertido] }
  validates :tema, inclusion: { in: TEMAS }
  validates :senha_publica_customizada, format: { with: /\A\d{4}\z/, message: "deve ter 4 dígitos numéricos" },
            allow_blank: true

  # Normaliza a senha customizada: mantém apenas dígitos e limita a 4.
  before_validation :normalizar_senha_customizada

  paginates_per 30

  def recalcular_total!
    subtotal = itens_orcamentos.sum { |i| (i.valorunitario || 0) * (i.quantidade || 0) }
    update_columns(valortotal: subtotal - (desconto || 0) + (acrescimo || 0))
  end

  def convertido?
    status == 'convertido' || cod_venda.present?
  end

  def pode_converter?
    !convertido? && status != 'rejeitado'
  end

  def converter_em_venda!(tipo_venda = 'V')
    return false unless pode_converter?

    ActiveRecord::Base.transaction do
      venda = Venda.new(
        tipo: tipo_venda,
        cod_empresa: cod_empresa,
        cod_pessoa: cod_pessoa,
        cod_funcionario: cod_funcionario,
        datavenda: Time.current,
        valortotal: valortotal,
        desconto: 0,
        acrescimo: 0,
        cancelada: false
      )

      itens_orcamentos.each do |item|
        venda.itensvenda.build(
          cod_produto: item.cod_produto,
          cod_cor: item.cod_cor,
          cod_empresa: item.cod_empresa,
          quantidade: item.quantidade,
          valorunitario: item.valorunitario,
          valor_desconto: item.valor_desconto,
          valor_acrescimo: item.valor_acrescimo
        )
      end

      venda.contas.build(
        cod_empresa: cod_empresa,
        ativo: true,
        quitada: false,
        numeroparcela: 1,
        dtvencimento: Date.current,
        valorparcela: valortotal,
        cod_tppagamento: 1
      )

      venda.save!
      update!(status: 'convertido', cod_venda: venda.cod_venda)
      venda
    end
  end

  # Sugestão de senha: os 4 últimos dígitos do celular/telefone do cliente.
  # Serve apenas como valor pré-preenchido na UI — não é a senha efetiva.
  def sugestao_senha
    numeros = [pessoa&.celular, pessoa&.telefone].compact.map { |valor| valor.to_s.gsub(/\D/, '') }.reject(&:blank?)
    telefone = numeros.first
    return '' if telefone.blank?

    telefone[-4, 4].to_s
  end

  # Senha efetivamente exigida: a customizada, se definida; senão, a sugestão do telefone.
  def senha_publica
    return senha_publica_customizada if senha_publica_customizada.present?

    sugestao_senha
  end

  def share_phone_last4
    sugestao_senha
  end

  # O link só pede senha quando o vendedor optou por protegê-lo.
  def link_requer_senha?
    link_protegido?
  end

  def senha_publica_valida?(senha)
    return true unless link_requer_senha?

    senha.to_s.gsub(/\D/, '') == senha_publica.to_s.gsub(/\D/, '')
  end

  def ensure_share_token!
    update_column(:share_token, SecureRandom.urlsafe_base64(24)) if share_token.blank?
  end

  def share_blocked?
    share_blocked_until.present? && share_blocked_until > Time.current
  end

  def link_expirado?
    # Prioridade 1: expiração explícita escolhida pelo vendedor (24h/48h/7d).
    return Time.current > link_expira_em if link_expira_em.present?

    # Prioridade 2 (comportamento antigo): validade do orçamento.
    if data_validade.present?
      return Date.current > data_validade.to_date
    end

    status != 'pendente'
  end

  # Traduz a opção escolhida (chave de VALIDADES_LINK) em link_expira_em.
  # "orcamento" (ou vazio) limpa a expiração explícita e volta ao comportamento antigo.
  def aplicar_validade_link(opcao)
    chave = opcao.to_s
    duracao = VALIDADES_LINK[chave]

    if chave == "orcamento" || chave.blank?
      self.link_expira_em = nil
    elsif duracao
      self.link_expira_em = Time.current + duracao
    end
  end

  # Retorna a chave de VALIDADES_LINK que melhor representa o estado atual.
  # Usado para pré-selecionar o <select> na UI.
  def opcao_validade_atual
    link_expira_em.present? ? "custom" : "orcamento"
  end

  def tem_fotos?
    itens_orcamentos.includes(:fotos).any? { |item| item.foto_principal.present? }
  end

  def link_publico_disponivel?
    tem_fotos? && !link_expirado?
  end

  private

  def normalizar_senha_customizada
    return if senha_publica_customizada.nil?

    apenas_digitos = senha_publica_customizada.to_s.gsub(/\D/, '')
    self.senha_publica_customizada = apenas_digitos.presence && apenas_digitos[0, 4]
  end
end
