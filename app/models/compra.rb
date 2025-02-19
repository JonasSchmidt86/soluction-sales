class Compra < ApplicationRecord

    self.table_name = "compra"

    self.primary_key = "cod_compra"

    belongs_to :frete, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :compra, dependent: :destroy, optional: true, autosave: true
    
    has_many :itenscompra, :class_name => 'Itemcompra', :foreign_key => 'cod_compra', inverse_of: :compra, autosave: true, dependent: :destroy
    accepts_nested_attributes_for :itenscompra, allow_destroy: true, update_only: true, reject_if: :all_blank

    has_many :contas, :class_name => 'Contaspagrec', :foreign_key => 'cod_compra', inverse_of: :compra, autosave: true, dependent: :destroy
    accepts_nested_attributes_for :contas, allow_destroy: true, update_only: true, reject_if: :all_blank

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :compras, autosave: true
    accepts_nested_attributes_for :pessoa, allow_destroy: false

    belongs_to :empresa, :class_name => 'Empresa', :foreign_key => 'cod_empresa'
    
    belongs_to :collaborator, :class_name => 'Funcionario', :foreign_key => 'cod_funcionario', inverse_of: :compras

    has_one :xml_file, autosave: true

    # after_save :atualizar_codigo_no_xml_file
    
    def compra_nfe
      if self.cancelada
          return ["CANCELADA", (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
      else
          return [self.cod_compraempresa, (self.numeronf.blank? ? "0" : self.numeronf)].join(' / ')
      end
  end

  def acrescimo_total
    # tudo que for acrescimo do item ou da nota
    0;
  end

    def valorPago
      valor = 0
      unless self.cancelada
        for conta in self.contas do
          unless conta.lancamentos.blank?
            for launch in conta.lancamentos do
                valor += launch.valor
                puts "\n valor Pago: #{valor} \n"
            end
          end
        end
      end
      return valor
    end

    def atualizar_codigo_no_xml_file
        if xml_file.present?
          xml_file.update_attributes(compra_id: self.codigo)
        end
      end
end
