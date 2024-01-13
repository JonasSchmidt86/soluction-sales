class Funcionarioempresa < ApplicationRecord

    self.table_name = "funcionarioempresa"
    self.primary_key = "cod_funcionarioempresa"

    belongs_to :empresa, :class_name => 'Empresa', 
                :foreign_key => 'cod_empresa'
    
    belongs_to :funcionario, :class_name => 'Funcionario', 
                :foreign_key => 'cod_funcionario', inverse_of: :funcionariosempresa

    validates_uniqueness_of :cod_empresa, scope: :cod_funcionario
    
    def nome_empresa
        if !empresa.blank?
            empresa.nome
            end
    end 

    def id_empresa
        if !empresa.blank?
            empresa.cod_empresa
        end
    end 

    paginates_per 10    

end
