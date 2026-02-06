class Orcamento < ApplicationRecord
  self.table_name = "orcamentos"
  self.primary_key = "cod_orcamento"

  attr_accessor :nome_pessoa

  has_many :itens_orcamentos, class_name: 'ItemOrcamento', foreign_key: 'cod_orcamento', 
           inverse_of: :orcamento, dependent: :destroy, autosave: true
  accepts_nested_attributes_for :itens_orcamentos, allow_destroy: true, 
    reject_if: proc { |attr| attr['cod_produto'].blank? && attr['quantidade'].to_f <= 0 }

  belongs_to :pessoa, class_name: 'Pessoa', foreign_key: 'cod_pessoa'
  belongs_to :funcionario, class_name: 'Funcionario', foreign_key: 'cod_funcionario'
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'cod_empresa'
  belongs_to :venda, class_name: 'Venda', foreign_key: 'cod_venda', optional: true

  validates :pessoa, :funcionario, :empresa, :data_orcamento, presence: true
  validates :status, inclusion: { in: %w[pendente aprovado rejeitado convertido] }

  paginates_per 30

  def convertido?
    status == 'convertido' || cod_venda.present?
  end

  def pode_converter?
    !convertido? && status != 'rejeitado'
  end

  def converter_em_venda!(tipo_venda = 'V')
    return false unless pode_converter?

    ActiveRecord::Base.transaction do
      venda = Venda.new(
        tipo: tipo_venda,
        cod_empresa: cod_empresa,
        cod_pessoa: cod_pessoa,
        cod_funcionario: cod_funcionario,
        datavenda: Time.current,
        valortotal: valortotal,
        desconto: 0,
        acrescimo: 0,
        cancelada: false
      )

      itens_orcamentos.each do |item|
        venda.itensvenda.build(
          cod_produto: item.cod_produto,
          cod_cor: item.cod_cor,
          cod_empresa: item.cod_empresa,
          quantidade: item.quantidade,
          valorunitario: item.valorunitario,
          valor_desconto: item.valor_desconto,
          valor_acrescimo: item.valor_acrescimo
        )
      end

      venda.contas.build(
        cod_empresa: cod_empresa,
        ativo: true,
        quitada: false,
        numeroparcela: 1,
        dtvencimento: Date.current,
        valorparcela: valortotal,
        cod_tppagamento: 1
      )

      venda.save!
      update!(status: 'convertido', cod_venda: venda.cod_venda)
      venda
    end
  end
end
