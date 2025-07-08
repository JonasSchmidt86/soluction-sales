class AddValorAcrescimoAndValorDescontoToItemvenda < ActiveRecord::Migration[7.1]
  def change
    add_column :itemvenda, :valor_acrescimo, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :itemvenda, :valor_desconto, :decimal, precision: 10, scale: 2, default: 0.0
  end
end