class MelhoriaHistorico < ApplicationRecord

  # === Associações ===
  belongs_to :melhoria
  belongs_to :funcionario, class_name: 'Funcionario', foreign_key: 'cod_funcionario',
             primary_key: 'cod_funcionario'

  # === Validações ===
  validates :campo, presence: true

  # === Scopes ===
  scope :cronologico, -> { order(created_at: :asc) }

  # === Helpers ===
  def autor_nome
    funcionario&.pessoa_nome || funcionario&.usuario || "Funcionário ##{cod_funcionario}"
  end

  def descricao_alteracao
    case campo
    when 'status'
      "alterou o status de \"#{valor_anterior_label}\" para \"#{valor_novo_label}\""
    when 'prioridade'
      "alterou a prioridade de \"#{valor_anterior_label}\" para \"#{valor_novo_label}\""
    when 'responsavel'
      if valor_anterior.blank?
        "definiu o responsável como \"#{valor_novo}\""
      else
        "alterou o responsável de \"#{valor_anterior}\" para \"#{valor_novo}\""
      end
    else
      "alterou #{campo} de \"#{valor_anterior}\" para \"#{valor_novo}\""
    end
  end

  private

  def valor_anterior_label
    traduzir_valor(campo, valor_anterior)
  end

  def valor_novo_label
    traduzir_valor(campo, valor_novo)
  end

  def traduzir_valor(campo_nome, valor)
    return valor if valor.blank?

    case campo_nome
    when 'status'
      {
        'aberto' => 'Aberto', 'analisando' => 'Analisando',
        'em_desenvolvimento' => 'Em Desenvolvimento', 'em_teste' => 'Em Teste',
        'concluido' => 'Concluído', 'recusado' => 'Recusado'
      }[valor] || valor
    when 'prioridade'
      {
        'baixa' => 'Baixa', 'normal' => 'Normal',
        'alta' => 'Alta', 'urgente' => 'Urgente'
      }[valor] || valor
    else
      valor
    end
  end

end
