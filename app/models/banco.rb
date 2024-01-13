class Banco < ApplicationRecord

    self.table_name = "banco"
    self.primary_key = "cod_banco"

    has_many :bancoconta, :class_name => 'Bancoconta', :foreign_key => 'cod_banco', inverse_of: :bancos

end
