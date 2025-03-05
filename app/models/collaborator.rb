class Collaborator < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  
  self.primary_key = "id"

  devise :database_authenticatable, :recoverable, :rememberable, :validatable #, :registerable

  belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', optional: false
  
  accepts_nested_attributes_for :funcionario, update_only: true, reject_if: :all_blank
  
  belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', optional: false

  # validates :email, presence: :true, on: :update, unless: :reset_password_token_present?

  validates :password, presence: true, if: -> { encrypted_password.blank? && new_record? }

  def reset_password_token_present?
    # !! duas exclamaçoes retorna valor boleano, se trouxer o token ele não faz o validate
    # params não pode ser acessado no model, para isso precisa criar uma variavel global onde o sistema passa
    puts "GLOBAL"
    !!global_params[:collaborator][:reset_password_token]
  end
  
  private 
  
  def pessoa_nome
    funcionario.pessoa.nome
  end

  paginates_per 5
end
