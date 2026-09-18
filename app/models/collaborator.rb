class Collaborator < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  
  self.primary_key = "id"

  devise :database_authenticatable, :recoverable, :rememberable, :validatable #, :registerable

  belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', optional: false
  
  accepts_nested_attributes_for :funcionario, update_only: true, reject_if: :all_blank
  
  belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', optional: false

  # Mensagem única reaproveitada na validação e exibida ao colaborador nas telas de senha.
  PASSWORD_RULE_MESSAGE = "deve ter no mínimo 8 caracteres, incluindo ao menos uma letra e um número".freeze

  # Quantidade mínima de dígitos para avaliar a regra de "sequência".
  # Com menos que isso (ex.: apenas "13") não faz sentido falar em sequência.
  MIN_SEQUENCIA_NUMERICA = 3

  validates :password, presence: true, if: :password_required?
  validates :password,
            length: { minimum: 8 },
            format: { with: /\A(?=.*[A-Za-z])(?=.*\d).+\z/, message: PASSWORD_RULE_MESSAGE },
            if: :password_required?
  validate :password_nao_previsivel, if: :password_required?

  def password_required?
    # Não exige senha se os campos estão vazios (para criação sem senha)
    return false if password.blank? && password_confirmation.blank?
    # Exige senha apenas se está sendo definida
    !password.blank?
  end

  # Verifica se precisa definir senha pela primeira vez
  def needs_password_setup?
    encrypted_password.blank?
  end

  # Palavras derivadas do nome e do e-mail que não podem aparecer na senha.
  # Exposto para a tela de senha espelhar a regra no checklist ao vivo.
  # Considera apenas termos com 4+ caracteres para evitar falsos positivos.
  def palavras_proibidas_senha
    termos = []

    termos << email.split("@").first.to_s.downcase if email.present?

    nome = safe_pessoa_nome
    termos.concat(nome.downcase.split(/[^a-z0-9]+/i)) if nome.present?

    termos.map { |t| t.gsub(/[^a-z0-9]/i, "") }
          .select { |t| t.length >= 4 }
          .uniq
  end

  private

  # Bloqueia os padrões previsíveis mais comuns:
  # 1) nome do colaborador ou parte do e-mail dentro da senha (ex.: "jonas1234")
  # 2) sequências numéricas óbvias (ex.: "1234", "123456")
  def password_nao_previsivel
    return if password.blank?

    senha = password.downcase

    palavras_proibidas_senha.each do |termo|
      if senha.include?(termo)
        errors.add(:password, "não pode conter o seu nome ou parte do seu e-mail")
        break
      end
    end

    if sequencia_numerica_consecutiva?(senha)
      errors.add(:password, "os números não podem ser uma sequência (ex.: 123, 1234) nem repetição (ex.: 0000, 1111). Misture os dígitos.")
    end
  end

  # Considera previsível quando TODOS os dígitos da senha, na ordem em que
  # aparecem, formam uma única sequência consecutiva (crescente ou decrescente)
  # OU são todos iguais (repetição).
  # Ex.: "senha123" -> "123" (escadinha) => bloqueia.
  #      "senha1111" -> "1111" (repetido) => bloqueia.
  #      "senha123546" -> "123546" (quebra no 5) => passa.
  # Exige ao menos MIN_SEQUENCIA_NUMERICA dígitos para a regra valer.
  def sequencia_numerica_consecutiva?(texto)
    digitos = texto.gsub(/\D/, "")
    return false if digitos.length < MIN_SEQUENCIA_NUMERICA

    numeros = digitos.chars.map(&:to_i)
    passos = numeros.each_cons(2).map { |a, b| b - a }

    # +1 (crescente), -1 (decrescente) ou 0 (todos iguais) em todos os passos.
    passos.all? { |p| p == 1 } ||
      passos.all? { |p| p == -1 } ||
      passos.all? { |p| p.zero? }
  end

  # Acessa o nome sem estourar erro caso a associação não esteja disponível.
  def safe_pessoa_nome
    funcionario&.pessoa&.nome
  rescue StandardError
    nil
  end

  def pessoa_nome
    funcionario.pessoa.nome
  end

  paginates_per 30
end
