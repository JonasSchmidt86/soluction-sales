class Bancoconta < ApplicationRecord

    self.table_name = "bancoconta"
    self.primary_key = "cod_bancoconta"

    has_many :lancamentos, :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_bancoconta', inverse_of: :bancoconta
    belongs_to :bancos, :class_name => 'Banco', :foreign_key => 'cod_banco', inverse_of: :bancoconta

end
