# Item de um DocumentoFiscal (nota em elaboracao / rascunho editavel).
# Persistido para permitir editar a nota antes de emitir — antes os itens da
# avulsa eram efemeros. Vale para avulsa e para NF de venda editada.
#
# Aceita valores em formato BR ("1.234,56") vindos do form (via MoedaBr).
class DocumentoFiscalItem < ApplicationRecord
  include MoedaBr

  self.table_name  = "documento_fiscal_item"
  self.primary_key = "cod_documento_fiscal_item"

  moeda_br :quantidade, :valorunitario, :valor_total

  belongs_to :documento_fiscal, class_name: "DocumentoFiscal",
             foreign_key: "cod_documento_fiscal", primary_key: "cod_documento_fiscal",
             inverse_of: :itens

  belongs_to :produto, class_name: "Produto",
             foreign_key: "cod_produto", primary_key: "cod_produto", optional: true

  belongs_to :perfil_tributario, class_name: "PerfilTributario",
             foreign_key: "cod_perfil_tributario", primary_key: "cod_perfil_tributario",
             optional: true

  validates :cod_produto, presence: true
  validates :quantidade, numericality: { greater_than: 0 }

  # Recalcula o total a partir de quantidade * valor unitario (a nota nao tem
  # acrescimo/desconto por item; se precisar no futuro, ajustar aqui).
  before_validation :calcular_total

  private

  def calcular_total
    self.valor_total = quantidade.to_d * valorunitario.to_d
  end
end
