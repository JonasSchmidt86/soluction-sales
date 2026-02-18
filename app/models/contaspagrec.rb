class Contaspagrec < ApplicationRecord

   default_scope { order(dtvencimento: :asc) }

    self.table_name = "contaspagrec"
    self.primary_key = "cod_contaspagrec"
        
    has_many :lancamentos, :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_contaspagrec', dependent: :delete_all, 
            inverse_of: :contaspagrec #, dependent: :destroy

    has_many :tiposlancamento, :class_name => 'Tiposlancamento', :foreign_key => 'cod_tppagamento', inverse_of: :contas
    accepts_nested_attributes_for :lancamentos, reject_if: :all_blank, allow_destroy: true #cocoon gem

    belongs_to :venda, :class_name => 'Venda', :foreign_key => 'cod_venda', inverse_of: :contas, optional: true
    
    belongs_to :compra, :class_name => 'Compra', :foreign_key => 'cod_compra', inverse_of: :contas, optional: true
    
    belongs_to :frete, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :contas, optional: true

    belongs_to :pessoa, foreign_key: :cod_pessoa, optional: true

    belongs_to :tiposhistoricocaixa,:class_name => 'Tiposhistoricoscaixa',
           foreign_key: :cod_tphitorico,
           optional: true

    belongs_to :funcionario, :class_name => 'Funcionario',
           foreign_key: :cod_funcionario,
           optional: true

    validate :origem_ou_descricao

    def origem_ou_descricao
        tem_origem = venda.present? || compra.present? || frete.present?
        tem_descricao = descricao.present?

        unless tem_origem || tem_descricao
            errors.add(:base, "Informe uma origem ou uma descrição para a conta.")
        end
    end

    def natureza_calculada
        return natureza if self[:natureza].present?

        if venda.present?
            0
        elsif compra.present? || frete.present?
            1
        end
    end

    def historico_exibicao
        return cod_tphitorico if self[:cod_tphitorico].present?
         if venda.present?
            1
         elsif compra.present?
            2
         else
            6
         end
         
     end

    def quitada_ext
        if self.ativo
            self.quitada? ? "Liquidada" : "Aberto"
        else
            "Cancelada"
        end
    end

    def dt_vencimento
        if !self.dtvencimento.nil?
            return post_date self.dtvencimento
        end
    end

    def nmParcela
        if venda.present?
            [venda.cod_vendaempresa, numeroparcela].join('-')

        elsif compra.present?
            if frete.present?
            [frete.nrromaneio, "F", frete.pessoa&.nome].join('-')
            else
            if compra.numeronf.blank?
                ["S/N", numeroparcela].join('-')
            else
                [compra.numeronf, numeroparcela].join('-')
            end
            end

        elsif frete.present? && frete.compra.present?
            if frete.compra.numeronf.blank?
            [frete.nrromaneio.to_i, "F"].join('-')
            else
            [frete.compra.numeronf, "F"].join('-')
            end
        else
            numeroparcela.to_s
        end
    end


    def nmPessoa 
        if !self.venda.nil?
            self.venda.pessoa.nome
        elsif !self.compra.nil?
            self.compra.pessoa.nome
        elsif !self.frete.nil?
            [self.frete.pessoa.nome[0,40], self.frete.compra.pessoa.nome[0,15]].join(' - ')
        else
            if pessoa.present? 
                pessoa.nome + " - " + descricao.to_s
            else
                descricao.to_s
            end
        end 
    end

    def nmCollaborator 
        if funcionario.present?
            funcionario.usuario
        else
            if !self.venda.nil?
                self.venda.funcionario.usuario
            elsif !self.compra.nil?
                self.compra.collaborator.usuario
            elsif !self.frete.nil?
                unless self.frete.compra.blank?
                    self.frete.compra.collaborator.usuario
                end
            end 
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
                        if conta.tipo == 'S'
                            valor += conta.valor
                        else
                            if !conta.cancelada?
                                valor -= conta.valor
                            end
                        end
                    end
                end
            end
        end
        return valor
    end
    paginates_per 30;
end

