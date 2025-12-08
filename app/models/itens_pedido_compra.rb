class ItensPedidoCompra < ApplicationRecord
  belongs_to :pedidos_compra
  belongs_to :produto, foreign_key: :cod_produto, primary_key: :cod_produto
  belongs_to :cor, :class_name => 'Core', foreign_key: :cod_cor, primary_key: :cod_cor, optional: true
  
  validates :cod_produto, :quantidade, :valor_unitario, :valor_total, presence: true
  validates :quantidade, :valor_unitario, numericality: { greater_than: 0 }
  
  before_save :calcular_valores
  
  def valor_total
    quantidade_val = self.quantidade || 0
    valor_unitario_val = self.valor_unitario || 0
    percentual_ipi_val = self.percentual_ipi || 0
    percentual_icms_val = self.percentual_icms || 0
    
    valorComImpostos = quantidade_val * (1 + (percentual_ipi_val / 100)) * (1 + (percentual_icms_val / 100));
    return valor_total = valor_unitario_val * valorComImpostos;
  end
  
  private
  
  def calcular_valores
    self.valor_ipi = (valor_unitario * quantidade * percentual_ipi / 100).round(2)
    self.valor_icms = (valor_unitario * quantidade * percentual_icms / 100).round(2)
    valor_total = (quantidade * valor_unitario + valor_ipi + valor_icms).round(2)
    self.valor_total = valor_total
  end
end