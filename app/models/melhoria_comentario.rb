class MelhoriaComentario < ApplicationRecord

  # === Associações ===
  belongs_to :melhoria
  belongs_to :funcionario, class_name: 'Funcionario', foreign_key: 'cod_funcionario',
             primary_key: 'cod_funcionario'

  # === Active Storage ===
  has_many_attached :anexos

  # === Validações ===
  validates :comentario, presence: true
  validate :anexos_validos

  # === Scopes ===
  scope :cronologico, -> { order(created_at: :asc) }

  # === Helpers ===
  def autor_nome
    funcionario&.pessoa_nome || funcionario&.usuario || "Funcionário ##{cod_funcionario}"
  end

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
