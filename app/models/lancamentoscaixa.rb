class Lancamentoscaixa < ApplicationRecord

    self.table_name = "lancamentoscaixa"
    self.primary_key = "cod_lancamentocaixa"

    belongs_to :caixa,       :class_name => 'Caixa',                :foreign_key => 'caixa_id', inverse_of: :lancamentoscaixa

    belongs_to :empresa,     :class_name => 'Empresa',              :foreign_key => 'cod_empresa' #, inverse_of: :lancamentos
    
    belongs_to :funcionario, :class_name => 'Funcionario',          :foreign_key => 'cod_funcionario' #, inverse_of: :lancamentos
    
    belongs_to :historico,   :class_name => 'Tiposhistoricoscaixa', :foreign_key => 'cod_tphitorico', inverse_of: :lancamentos
    
    belongs_to :contaspagrec,:class_name => 'Contaspagrec',         :foreign_key => 'cod_contaspagrec', inverse_of: :lancamentos, optional: :true, :autosave => true
    
    belongs_to :pessoa,      :class_name => 'Pessoa',               :foreign_key => 'cod_pessoa', inverse_of: :lancamentos, optional: :true

    def nmPessoa 
        if self.pessoa.nil?
            if !self.contaspagrec.nil?
                self.contaspagrec.nmPessoa
            else
                self.descricao
            end
        else
            self.pessoa.nome
        end
    end

    def nmParcela
        if self.contaspagrec.nil?
            "LC"
        else
            self.contaspagrec.nmParcela
        end
    end

    def historico_descricao
        if self.descricao?
            self.descricao
        else
            self.historico.descricao
        end
    end

    paginates_per 15

end
