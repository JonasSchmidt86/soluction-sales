class Atendimento < ApplicationRecord
  belongs_to :origem, optional: true
  belongs_to :empresa, foreign_key: :cod_empresa, primary_key: :cod_empresa, optional: true
  belongs_to :pessoa, foreign_key: :cod_cliente, primary_key: :cod_pessoa, optional: true
  belongs_to :funcionario, foreign_key: :cod_funcionario, primary_key: :cod_funcionario, optional: true

  validates :cod_empresa, presence: true
  validates :data_atendimento, presence: true
end
