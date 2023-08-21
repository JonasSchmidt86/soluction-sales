class Contaspagrec < ApplicationRecord

    self.table_name = "contaspagrec"
    self.primary_key = "cod_contaspagrec"
        
    has_many :lancamentos, :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_contaspagrec', 
            inverse_of: :contaspagrec, dependent: :destroy

    accepts_nested_attributes_for :lancamentos, reject_if: :all_blank, allow_destroy: true #cocoon gem

    belongs_to :venda, :class_name => 'Venda', :foreign_key => 'cod_venda', inverse_of: :contas, optional: true

    belongs_to :compra, :class_name => 'Compra', :foreign_key => 'cod_compra', inverse_of: :contas, optional: true
    
    belongs_to :frete, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :contas, optional: true

    def dt_vencimento
        if !self.dtvencimento.nil?
            return post_date self.dtvencimento
        end
    end

    def nmParcela
        if !self.venda.nil?
            [self.venda.cod_vendaempresa, self.numeroparcela].join('-')
        elsif !self.compra.nil?
            [self.compra.cod_compra, self.numeroparcela].join('-')
        elsif !self.frete.nil?
            [self.frete.nrromaneio, "F"].join('-')
        end
    end

    def nmPessoa 
        if !self.venda.nil?
            self.venda.pessoa.nome
        elsif !self.compra.nil?
            self.compra.pessoa.nome
        elsif !self.frete.nil?
            self.frete.pessoa.nome
        end 
    end

    def nmCollaborator 
        if !self.venda.nil?
            self.venda.funcionario.usuario
        elsif !self.compra.nil?
            self.compra.collaborator.usuario
        elsif !self.frete.nil?
            self.frete.pessoa.nome
        end 
    end

    def valorPago
        valor = 0
        if !self.lancamentos.blank?
            unless self.venda.blank?
                for conta in self.lancamentos do
                    if conta.historico != 14 # 14 credito cliente
                        if conta.tipo == 'E'
                            valor += conta.valor
                        end
                    end
                    if conta.tipo == 'S'
                        valor -= conta.valor
                    end
                end
            else
                
                if !self.compra.nil? || !self.frete.nil?
                    for conta in self.lancamentos do
                        if conta.tipo == 'E'
                            valor -= conta.valor
                        else
                            if !conta.cancelada?
                                valor += conta.valor
                            end
                        end
                    end
                end
            end
        end
        valor
    end
end

