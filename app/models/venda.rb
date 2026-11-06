class Venda < ApplicationRecord
    include MoedaBr

    self.table_name = "venda"
    self.primary_key = "cod_venda"

    # Aceita valores em formato BR ("1.234,56") vindos do form/nested attributes.
    moeda_br :valortotal, :acrescimo, :desconto

    # Recalcula o valortotal no SERVIDOR a partir dos itens (nao confia no campo
    # do form, que depende de JS e pode ficar defasado — ex.: ao remover um item
    # ja salvo). Roda antes da validacao, em create e update.
    before_validation :recalcular_valortotal

    after_commit :gerar_transferencia, if: -> { tipo == 'T' }

    # Soma dos itens que permanecem (ignora os marcados para remocao) ja com
    # acrescimo/desconto POR ITEM, mais o acrescimo/desconto do CABECALHO.
    def total_itens_calculado
        itens = itensvenda.reject(&:marked_for_destruction?)
        soma_itens = itens.sum { |i| i.valor_total || 0 }
        (soma_itens + (acrescimo || 0) - (desconto || 0)).round(2)
    end

    private

    def recalcular_valortotal
        # Transferencia gera contas/valores por outro fluxo; nao mexe aqui.
        return if transferencia?
        self.valortotal = total_itens_calculado
    end

    public

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

    # NF autorizada (modelo 55 NF-e OU 65 NFC-e) para esta venda? Enquanto
    # houver NF autorizada a venda nao pode ser editada (os itens divergiriam da
    # nota na SEFAZ) e nao se deve gerar outro rascunho pela venda.
    def nfe_autorizada
        DocumentoFiscal.where(cod_venda: cod_venda, modelo: [55, 65], status: "autorizada")
                       .order(cod_documento_fiscal: :desc).first
    end

    def nfe_autorizada?
        nfe_autorizada.present?
    end

    # Venda 100% concluida: tem parcelas e TODAS estao liquidadas no caixa
    # (valor recebido cobre o total). Nesse caso a venda esta "fechada" e nao
    # deve ser editada — para mudar o valor, estorne o pagamento antes.
    def totalmente_paga?
        return false if cancelada?
        return false if contas.empty?
        total = (valortotal || 0).round(2)
        return false if total <= 0
        valorRecebido.to_d.round(2) >= total
    end

    # Venda pode ser editada? Nao, se cancelada, com NF-e autorizada, ou se ja
    # esta 100% paga (concluida).
    def editavel?
        !cancelada? && !nfe_autorizada? && !totalmente_paga?
    end

    paginates_per 30

    # Usa a associacao ja carregada (includes) em vez de uma nova query por
    # venda. No relatorio de vendas isso elimina 3 queries por linha (N+1):
    # funcionario/empresa/pessoa ja vem pre-carregados. O &. protege quando
    # a associacao e nil.
    def nome_funcionario
        funcionario&.usuario
    end

    def nome_empresa
        empresa&.nome
    end

    def nome_pessoa 
        pessoa&.nome
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
