class Produtoxml < ApplicationRecord

    self.table_name = "produtoxml"
    self.primary_key = "codigo"

    attr_accessor :desconto  # campo temporario

    belongs_to :cor, :class_name => 'Core', :foreign_key => 'cod_cor' #, inverse_of: :cores
    
    belongs_to :produto, :class_name => 'Produto', :foreign_key => 'cod_produto', autosave: true

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa' #, inverse_of: :cores

end
