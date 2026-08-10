class Melhoria < ApplicationRecord

  self.table_name = "melhorias"

  # === Associações ===
  belongs_to :funcionario, class_name: 'Funcionario', foreign_key: 'cod_funcionario'
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'cod_empresa', primary_key: 'cod_empresa'
  belongs_to :responsavel, class_name: 'Funcionario', foreign_key: 'responsavel_id',
             primary_key: 'cod_funcionario', optional: true

  has_many :comentarios, class_name: 'MelhoriaComentario', dependent: :destroy
  has_many :historicos, class_name: 'MelhoriaHistorico', dependent: :destroy

  # === Active Storage ===
  has_many_attached :anexos

  # === Enums ===
  enum tipo: {
    sugestao: 0,
    erro: 1,
    melhoria: 2,
    nova_funcionalidade: 3
  }, _prefix: true

  enum status: {
    aberto: 0,
    analisando: 1,
    em_desenvolvimento: 2,
    em_teste: 3,
    concluido: 4,
    recusado: 5
  }, _prefix: true

  enum prioridade: {
    baixa: 0,
    normal: 1,
    alta: 2,
    urgente: 3
  }, _prefix: true

  # === Validações ===
  validates :titulo, presence: true, length: { maximum: 200 }
  validates :descricao, presence: true
  validates :tipo, presence: true
  validates :status, presence: true
  validates :prioridade, presence: true
  validate :anexos_validos

  # === Scopes ===
  scope :por_status, ->(status) { where(status: status) if status.present? }
  scope :por_tipo, ->(tipo) { where(tipo: tipo) if tipo.present? }
  scope :por_prioridade, ->(prioridade) { where(prioridade: prioridade) if prioridade.present? }
  scope :por_funcionario, ->(cod) { where(cod_funcionario: cod) if cod.present? }
  scope :por_empresa, ->(cod) { where(cod_empresa: cod) if cod.present? }
  scope :por_periodo, ->(inicio, fim) {
    where(created_at: inicio.beginning_of_day..fim.end_of_day) if inicio.present? && fim.present?
  }
  scope :busca, ->(termo) {
    where("titulo ILIKE :q OR descricao ILIKE :q", q: "%#{termo}%") if termo.present?
  }
  scope :recentes, -> { order(created_at: :desc) }

  # === Helpers ===
  def tipo_label
    {
      'sugestao' => 'Sugestão',
      'erro' => 'Erro',
      'melhoria' => 'Melhoria',
      'nova_funcionalidade' => 'Nova Funcionalidade'
    }[tipo]
  end

  def status_label
    {
      'aberto' => 'Aberto',
      'analisando' => 'Analisando',
      'em_desenvolvimento' => 'Em Desenvolvimento',
      'em_teste' => 'Em Teste',
      'concluido' => 'Concluído',
      'recusado' => 'Recusado'
    }[status]
  end

  def prioridade_label
    {
      'baixa' => 'Baixa',
      'normal' => 'Normal',
      'alta' => 'Alta',
      'urgente' => 'Urgente'
    }[prioridade]
  end

  def prioridade_cor
    {
      'baixa' => 'secondary',
      'normal' => 'warning',
      'alta' => 'danger',
      'urgente' => 'dark'
    }[prioridade]
  end

  def status_cor
    {
      'aberto' => 'primary',
      'analisando' => 'info',
      'em_desenvolvimento' => 'warning',
      'em_teste' => 'secondary',
      'concluido' => 'success',
      'recusado' => 'danger'
    }[status]
  end

  def tipo_icone
    {
      'sugestao' => 'fa-lightbulb-o',
      'erro' => 'fa-bug',
      'melhoria' => 'fa-arrow-up',
      'nova_funcionalidade' => 'fa-plus-circle'
    }[tipo]
  end

  def solicitante_nome
    funcionario&.pessoa_nome || funcionario&.usuario || "Funcionário ##{cod_funcionario}"
  end

  def responsavel_nome
    responsavel&.pessoa_nome || responsavel&.usuario
  end

  paginates_per 20

  private

  def anexos_validos
    return unless anexos.attached?

    anexos.each do |anexo|
      if anexo.byte_size > 10.megabytes
        errors.add(:anexos, "#{anexo.filename} excede o tamanho máximo de 10MB")
      end

      tipos_permitidos = %w[
        image/jpeg image/png image/gif image/webp
        application/pdf
        application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        text/plain
      ]

      unless tipos_permitidos.include?(anexo.content_type)
        errors.add(:anexos, "#{anexo.filename} possui formato não permitido")
      end
    end
  end

end
