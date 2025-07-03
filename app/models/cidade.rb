class Cidade < ApplicationRecord

    self.table_name = "cidade"
    self.primary_key = "cod_cidade"

    has_many :pessoas, :class_name => 'Pessoa', :foreign_key => 'cod_cidade', inverse_of: :cidade
    belongs_to :estado, :class_name => 'Estado', foreign_key: 'cod_estado'   

    def to_s
        nome + " - " + estado.sigla;
    end

end
