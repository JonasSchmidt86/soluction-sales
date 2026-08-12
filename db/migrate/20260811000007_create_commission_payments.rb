class CreateCommissionPayments < ActiveRecord::Migration[7.0]
  def change
    create_table :commission_payments do |t|
      t.references :commission_period, null: false, foreign_key: true
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.datetime :paid_at, null: false
      t.bigint :paid_by, null: false
      t.text :notes

      t.timestamps
    end
  end
end
