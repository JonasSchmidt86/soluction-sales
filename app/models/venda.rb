class Venda < ApplicationRecord
    include MoedaBr

    self.table_name = "venda"
    self.primary_key = "cod_venda"

    # Aceita valores em formato BR ("1.234,56") vindos do form/nested attributes.
    moeda_br :valortotal, :acrescimo, :desconto

    after_commit :gerar_transferencia, if: -> { tipo == 'T' }

    def gerar_transferencia
        if contas.any? || Contaspagrec.exists?(cod_venda: cod_venda)
            Rails.logger.info("[TransferenciaService] venda #{cod_venda}: pulou (já possui conta). contas=#{contas.size}")
            return
        end
        Rails.logger.info("[TransferenciaService] venda #{cod_venda}: iniciando geração (origem=#{cod_empresa} destino=#{cod_empresa_transferida})")
        TransferenciaService.new(self).call
        Rails.logger.info("[TransferenciaService] venda #{cod_venda}: concluído com sucesso")
    rescue => e
        # after_commit não faz rollback: logamos qualquer falha do service
        # para não ficar silenciosa (ex: empresa sem cod_bancoconta).
        Rails.logger.error("[TransferenciaService] falha ao gerar transferência da venda #{cod_venda}: #{e.class} - #{e.message}")
    end

    has_many :itensvenda, :class_name => 'Itemvenda', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :destroy, autosave: true
    # update_only nao se aplica a has_many (Rails ignora): o que faz UPDATE em
    # vez de INSERT e o :id presente em cada hash de itensvenda_attributes.
    # reject_if descarta apenas LINHAS NOVAS em branco (sem id e sem produto);
    # nunca descarta um item existente (com id), para nao perder a atualizacao.
    accepts_nested_attributes_for :itensvenda, allow_destroy: true,
        reject_if: ->(attrs) { attrs["id"].blank? && attrs["cod_produto"].blank? }

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_venda', inverse_of: :venda, dependent: :destroy, autosave: true
    # Descarta apenas parcelas NOVAS incompletas (sem id e sem numero/valor/
    # vencimento). Parcela existente (com id) nunca e descartada aqui; o
    # UPDATE/_destroy dela e tratado normalmente.
    accepts_nested_attributes_for :contas, allow_destroy: true,
        reject_if: ->(attrs) {
          attrs["id"].blank? &&
            (attrs["numeroparcela"].blank? || attrs["valorparcela"].blank? || attrs["dtvencimento"].blank?)
        }

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :vendas
    accepts_nested_attributes_for :pessoa, allow_destroy: false

    belongs_to :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :vendas
    
    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa', inverse_of: :vendas

    validates :itensvenda, :funcionario, :empresa, :pessoa, presence: true
    validates :contas, presence: true, unless: :transferencia?

    def transferencia?
        tipo == 'T'
    end

    # NF-e (modelo 55) autorizada para esta venda? Enquanto houver NF autorizada
    # a venda nao pode ser editada (os itens divergiriam da nota na SEFAZ).
    def nfe_autorizada
        DocumentoFiscal.where(cod_venda: cod_venda, modelo: 55, status: "autorizada")
                       .order(cod_documento_fiscal: :desc).first
    end

    def nfe_autorizada?
        nfe_autorizada.present?
    end

    # Venda pode ser editada? Nao, se cancelada ou com NF-e autorizada.
    def editavel?
        !cancelada? && !nfe_autorizada?
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
