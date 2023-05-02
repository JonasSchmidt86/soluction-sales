class Caixa < ApplicationRecord

    self.table_name = "caixa"
    self.primary_key = "id"

    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :lembretes
    
    belongs_to :funcionario_abertura, :class_name => 'Funcionario', :foreign_key => 'cod_funcionarioabertura', inverse_of: :funcionario_aberturas
    belongs_to :funcionario_fechamento, :class_name => 'Funcionario', :foreign_key => 'cod_funcionariofechamento', inverse_of: :funcionario_aberturas, optional: true

        
    has_many :lancamentoscaixa, :class_name => 'Lancamentoscaixa', :foreign_key => 'caixa_id', 
             inverse_of: :caixa

    def fechamento
        if self.datafechamento.blank?
            self.valorfechamento= (self.valorabertura + self.valorentradas) - self.valorsaidas
        else
            self.valorfechamento
        end
    end

    EVENTS = {
        caixa_aberto: @caixa
    };

    #scoop não pega quem esta logado
    scope :caixa_aberto , -> {
        where(" cod_empresa = ? and datafechamento is null ", current_collaborator.cod_empresa).last
      }

    paginates_per 30

end
