class Tiposhistoricoscaixa < ApplicationRecord

    
    self.table_name = "tiposhistoricoscaixa"
    self.primary_key = "cod_tphitorico"

    has_many :lancamentos,   :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_tphitorico', inverse_of: :historico
    
end
