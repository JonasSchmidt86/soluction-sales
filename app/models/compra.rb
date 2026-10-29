class Compra < ApplicationRecord

    self.table_name = "compra"

    self.primary_key = "cod_compra"

    belongs_to :frete, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :compra, dependent: :destroy, optional: true, autosave: true
    
    has_many :itenscompra, :class_name => 'Itemcompra', :foreign_key => 'cod_compra', inverse_of: :compra, autosave: true, dependent: :destroy
    accepts_nested_attributes_for :itenscompra, allow_destroy: true, update_only: true, reject_if: :reject_empty_items

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_compra', inverse_of: :compra, autosave: true, dependent: :destroy
    accepts_nested_attributes_for :contas, allow_destroy: true, update_only: true, reject_if: :reject_empty_contas

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :compras, autosave: true
    accepts_nested_attributes_for :pessoa, allow_destroy: false

    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa'
    
    belongs_to :collaborator, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :compras

    has_one :xml_file, autosave: true

    # Notas recebidas ligadas a esta compra. Ao EXCLUIR a compra, desliga as notas
    # (cod_compra = NULL) para voltarem a oferecer "Importar" em vez de apontar
    # para uma compra que nao existe mais. (O CANCELAMENTO e tratado no
    # ComprasController#destroy, que usa update_columns e nao dispara callbacks.)
    has_many :notas_recebidas, class_name: 'NotaRecebida', foreign_key: 'cod_compra',
             primary_key: 'cod_compra', dependent: :nullify

    validates :itenscompra, :contas, :collaborator, :empresa, :pessoa, presence: true

    # after_save :atualizar_codigo_no_xml_file

    # Quando a compra nasce de um XML (importacao de NF recebida), liga a
    # NotaRecebida a esta compra para a lista de Notas Recebidas mostrar o
    # carrinho (ver compra) em vez do botao Importar.
    after_save :vincular_nota_recebida
    
    def compra_nfe
      if self.cancelada
          return ["CANCELADA", (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
      else
        if self.nr_pedido
          return [self.cod_compraempresa, (self.nr_pedido.blank? ? "0" : self.nr_pedido)].join(' / P-')
        else
          return [self.cod_compraempresa, (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
        end
      end
  end

  # Compra pode gerar NF de devolucao quando tem NF (numero) e o XML anexado
  # (de onde sai a chave referenciada). Nao cancelada. A chave em si e extraida
  # do XML pelo Fiscal::DevolucaoCompraExtractor.
  def pode_devolver_nf?
    return false if cancelada?
    return false if numeronf.blank?
    xml_file&.file&.attached? ? true : false
  rescue StandardError
    false
  end

  def acrescimo_total
    # tudo que for acrescimo do item ou da nota
    0;
  end

  def nome_pessoa
    Pessoa.where(cod_pessoa: self.cod_pessoa).pluck(:nome).first
  end

  def self.pessoa 
      nome_pessoa
  end

  def funcionario
    Funcionario.where(id: self.cod_funcionario).pluck(:usuario).first
  end

  def valorPago
    return 0 if cancelada?

    Lancamentoscaixa
      .joins(:contaspagrec)
      .where(contaspagrec: { cod_compra: id })
      .sum(:valor)
  end

  def atualizar_codigo_no_xml_file
    if xml_file.present?
      xml_file.update_attributes(compra_id: self.codigo)
    end
  end

  private

  # Liga as notas recebidas que usam o XML desta compra (match exato por
  # xml_file_id, sem adivinhar por numero). Nao mexe em compra cancelada e nao
  # sobrescreve nota que ja esta ligada a outra compra.
  def vincular_nota_recebida
    return if cancelada? || xml_file.nil? || xml_file.id.blank?

    NotaRecebida.where(xml_file_id: xml_file.id, cod_compra: nil)
                .update_all(cod_compra: cod_compra)
  rescue => e
    Rails.logger.warn("[Compra#vincular_nota_recebida] compra #{cod_compra}: #{e.class} - #{e.message}")
  end

  def reject_empty_items(attributes)
    attributes['cod_produto'].blank? || attributes['quantidade'].blank? || attributes['valorunitario'].blank?
  end

  def reject_empty_contas(attributes)
    attributes['valorparcela'].blank? || attributes['dtvencimento'].blank?
  end
end
