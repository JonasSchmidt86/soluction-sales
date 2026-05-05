class Venda < ApplicationRecord

    self.table_name = "venda"
    self.primary_key = "cod_venda"

    after_commit :gerar_transferencia, if: -> { tipo == 'T' }

    def gerar_transferencia
        return if contas.any? || Contaspagrec.exists?(cod_venda: cod_venda)
        TransferenciaService.new(self).call
    end

    has_many :itensvenda, :class_name => 'Itemvenda', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :destroy, autosave: true
    accepts_nested_attributes_for :itensvenda, allow_destroy: true, update_only: true #, reject_if: :all_blank

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :destroy, autosave: true
    accepts_nested_attributes_for :contas, allow_destroy: true #, update_only: true , reject_if: :all_blank

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :vendas
    accepts_nested_attributes_for :pessoa, allow_destroy: false

    belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :vendas
    
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :vendas

    validates :itensvenda, :funcionario, :empresa, :pessoa, presence: true
    validates :contas, presence: true, unless: :transferencia?

    def transferencia?
        tipo == 'T'
    end

    paginates_per 30

    def nome_funcionario
        Funcionario.where(id: self.cod_funcionario).pluck(:usuario).first
    end

    def nome_empresa
        Empresa.where(cod_empresa: self.cod_empresa).pluck(:nome).first
    end

    def nome_pessoa 
        Pessoa.where(cod_pessoa: self.cod_pessoa).pluck(:nome).first
    end

    def venda_nfe
        if self.cancelada
            return ["CANCELADA", (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
        else
            return [self.cod_vendaempresa, (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
        end
    end

    def valorRecebido
        return 0 if cancelada?

        if self.transferencia?
            Lancamentoscaixa
                .joins(:contaspagrec)
                .where(contaspagrec: { cod_venda: id })
                .where.not(tipo: 'S')
                .sum("CASE WHEN tipo = 'E' THEN valor ELSE -valor END")
        else
            Lancamentoscaixa
                .joins(:contaspagrec)
                .where(contaspagrec: { cod_venda: id })
                .sum(:valor)
        end
    end

    def valorDevido
        valortotal - valorRecebido
    end
    
    def valorCusto
        valorCusto = 0;
        for item in self.itensvenda do 
            valorCusto += ((item.valororiginal || 0) * (item.quantidade || 0))
        end
        return valorCusto;
    end
    
end
