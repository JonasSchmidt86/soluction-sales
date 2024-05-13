class Tiposlancamento < ApplicationRecord

    self.table_name = "tiposlancamento"
    self.primary_key = "cod_tppagamento"
        
    has_many :lancamentos, :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :historico
    
    has_many :contas, :class_name => 'Contas', :foreign_key => 'cod_contaspagrec', inverse_of: :tiposlancamento

end
