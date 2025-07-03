class Estado < ApplicationRecord
    
    self.table_name = "estado"
    self.primary_key = 'cod_estado'  # Importante: define que a PK é cod_estado
    has_many :cidades, foreign_key: 'cod_estado'

end
