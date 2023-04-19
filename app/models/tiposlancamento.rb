class Tiposlancamento < ApplicationRecord

    self.table_name = "tiposhistoricoscaixa"
    self.primary_key = "cod_tphitorico"
        
    has_many :lancamentos, :class_name => 'LancamentosCaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :historico

end
