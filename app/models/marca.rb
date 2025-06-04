class Marca < ApplicationRecord
    
    self.table_name = "marca"
    self.primary_key = "cod_marca"

    has_many :produtos
    has_many :imagens, through: :produtos
   
    has_many :produtos, foreign_key: 'marca', class_name: 'Produto'
    has_many :produto_imagens, through: :produtos

    validates :nome, presence: true, uniqueness: { case_sensitive: false, message: "já está cadastrado" }

end
