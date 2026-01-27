class Collaborator < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  
  self.primary_key = "id"

  devise :database_authenticatable, :recoverable, :rememberable, :validatable #, :registerable

  belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', optional: false
  
  accepts_nested_attributes_for :funcionario, update_only: true, reject_if: :all_blank
  
  belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', optional: false

  validates :password, presence: true, if: :password_required?

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
  
  private 
  
  def pessoa_nome
    funcionario.pessoa.nome
  end

  paginates_per 30
end
