class CreateOrcamentos < ActiveRecord::Migration[7.1]
  def change
    create_table :orcamentos, primary_key: :cod_orcamento do |t|
      t.bigint :cod_empresa, null: false
      t.bigint :cod_pessoa, null: false
      t.bigint :cod_funcionario, null: false
      t.datetime :data_orcamento, null: false
      t.date :data_validade
      t.decimal :valortotal, precision: 18, scale: 2, default: 0.0
      t.decimal :desconto, precision: 18, scale: 3, default: 0.0
      t.decimal :acrescimo, precision: 18, scale: 3, default: 0.0
      t.string :status, limit: 20, default: 'pendente'
      t.text :observacoes
      t.bigint :cod_venda
      t.timestamps
    end

    add_foreign_key :orcamentos, :empresa, column: :cod_empresa, primary_key: :cod_empresa
    add_foreign_key :orcamentos, :pessoa, column: :cod_pessoa, primary_key: :cod_pessoa
    add_foreign_key :orcamentos, :funcionario, column: :cod_funcionario, primary_key: :cod_funcionario
    add_foreign_key :orcamentos, :venda, column: :cod_venda, primary_key: :cod_venda

    create_table :itens_orcamentos, primary_key: :cod_item do |t|
      t.bigint :cod_orcamento, null: false
      t.bigint :cod_produto, null: false
      t.bigint :cod_cor
      t.bigint :cod_empresa, null: false
      t.decimal :quantidade, precision: 18, scale: 2, default: 0.0
      t.decimal :valorunitario, precision: 18, scale: 2, default: 0.0
      t.decimal :valor_desconto, precision: 10, scale: 2, default: 0.0
      t.decimal :valor_acrescimo, precision: 10, scale: 2, default: 0.0
      t.timestamps
    end

    add_foreign_key :itens_orcamentos, :orcamentos, column: :cod_orcamento, primary_key: :cod_orcamento
    add_foreign_key :itens_orcamentos, :produto, column: :cod_produto, primary_key: :cod_produto
    add_foreign_key :itens_orcamentos, :cores, column: :cod_cor, primary_key: :cod_cor
    add_foreign_key :itens_orcamentos, :empresa, column: :cod_empresa, primary_key: :cod_empresa
  end
end
