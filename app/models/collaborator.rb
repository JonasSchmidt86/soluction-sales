class Collaborator < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario'
  
  accepts_nested_attributes_for :funcionario, update_only: true, reject_if: :all_blank
  
  belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa'

  # validates :email, presence: :true, on: :update, unless: :reset_password_token_present?

  def reset_password_token_present?
    # !! duas exclamaçoes retorna valor boleano, se trouxer o token ele não faz o validate
    # params não pode ser acessado no model, para isso precisa criar uma variavel global onde o sistema passa
    puts "GLOBAL"
    puts "asdasdas" + global_params[:collaborator][:reset_password_token]
    !!global_params[:collaborator][:reset_password_token]
  end
  
  def pessoa_nome
    funcionario.pessoa.nome
  end

  paginates_per 5
end
