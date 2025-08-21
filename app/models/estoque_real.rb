class EstoqueReal < ApplicationRecord
  self.table_name  = "view_estoque_real"
  self.primary_key = nil

  def readonly?
    true
  end
end