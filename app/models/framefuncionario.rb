class Framefuncionario < ApplicationRecord

    self.table_name = "framefuncionario"
    self.primary_key = "cod_frame"

    belongs_to :funcionarioempresas, foreign_key: 'cod_frame', inverse_of: :framefuncionario
end
