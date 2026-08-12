class CreateCommissionPeriodSales < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_period_sales do |t|
      t.references :commission_period, null: false, foreign_key: true
      t.bigint :cod_venda, null: false
      t.decimal :sale_value, precision: 18, scale: 2, null: false
      t.datetime :sale_date, null: false
      t.decimal :commission_amount, precision: 18, scale: 2, null: false

      t.timestamps
    end

    add_index :commission_period_sales, [:commission_period_id, :cod_venda],
              unique: true, name: 'idx_commission_period_sales_period_venda'
    add_index :commission_period_sales, :cod_venda
  end
end
