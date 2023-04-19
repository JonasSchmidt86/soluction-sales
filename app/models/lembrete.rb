class Lembrete < ApplicationRecord

    self.table_name = "lembretes"
    self.primary_key = "codigo"

    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :lembretes
    belongs_to :empresaSol, :class_name => 'Empresa', :foreign_key => 'cod_empresasolicitada', optional: true
    belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario'

    paginates_per 20

end
