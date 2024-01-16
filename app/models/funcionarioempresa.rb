class Funcionarioempresa < ApplicationRecord

    self.table_name = "funcionarioempresa"
    self.primary_key = "cod_funcionarioempresa"


    # belongs_to :empresa, :class_name => 'Empresa', 
    #             :foreign_key => 'cod_empresa', inverse_of: :funcionariosempresa

    # belongs_to :funcionario, :class_name => 'Funcionario', 
    #             :foreign_key => 'cod_funcionario', inverse_of: :funcionariosempresa

    # validates_uniqueness_of :empresa, scope: :funcionario


    belongs_to :funcionario, foreign_key: 'cod_funcionario', inverse_of: :funcionarioempresas
    belongs_to :empresa, foreign_key: 'cod_empresa', inverse_of: :funcionarioempresas

    validates_uniqueness_of :empresa, scope: :funcionario
    
    def nome_empresa
        if !empresa.blank?
            self.empresa.nome
        end
    end 

    def id_empresa
        if !empresa.blank?
            self.empresa.cod_empresa
        end
    end 

    paginates_per 30

end
