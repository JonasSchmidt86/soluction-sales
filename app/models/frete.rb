class Frete < ApplicationRecord

    self.table_name = "frete"
    self.primary_key = "cod_frete"

    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :fretes

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :fretes

    has_many :contas, :class_name => 'contaspagrec', :foreign_key => 'cod_lfrete' #, inverse_of: :frete

    paginates_per 10    

end
