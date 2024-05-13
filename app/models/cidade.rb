class Cidade < ApplicationRecord

    self.table_name = "cidade"
    self.primary_key = "cod_cidade"

    has_many :pessoas, :class_name => 'Pessoa', :foreign_key => 'cod_cidade', inverse_of: :cidade

    def to_s
        nome;
    end

end
