class CreateFiscalProduto < ActiveRecord::Migration[7.1]
  def change
    # Dados fiscais do produto POR EMPRESA (antes ficavam no cadastro global
    # do produto, o que impedia cada empresa ter seu proprio perfil/regime).
    #
    # Escopo: cadastro fiscal (ncm/cest/origem/gtin/csosn/perfil) + estoque
    # fiscal CONSOLIDADO por produto (qtd_fiscal = soma de todas as cores).
    #
    # Importante:
    #  - CFOP/CSOSN aqui sao dado de CADASTRO/ENTRADA (informativo). Na EMISSAO
    #    (saida) o CFOP/CSOSN vem SEMPRE da regra do perfil tributario.
    #  - A qtdfiscal POR COR continua em empresaproduto (triggers intactas).
    #    Esta qtd_fiscal e o total consolidado por produto, para controle interno.
    unless table_exists?(:fiscal_produto)
      create_table :fiscal_produto, primary_key: :cod_fiscal_produto do |t|
        t.bigint  :cod_empresa, null: false
        t.bigint  :cod_produto, null: false

        # Cadastro fiscal (por empresa)
        t.string  :ncm,    limit: 8,  comment: "NCM (8 digitos)"
        t.bigint  :cfop,              comment: "CFOP de ENTRADA (cadastro/referencia; saida usa a regra)"
        t.string  :cest,   limit: 7,  comment: "CEST (7 digitos)"
        t.string  :origem, limit: 1,  comment: "origem da mercadoria (0..8)"
        t.string  :gtin,   limit: 14, comment: "codigo de barras (EAN/GTIN)"
        t.string  :csosn,  limit: 4,  comment: "CSOSN de cadastro/referencia (saida usa a regra)"

        # Perfil tributario que resolve CSOSN/CFOP na saida
        t.bigint  :cod_perfil_tributario, comment: "FK logica para perfil_tributario"

        # Estoque fiscal consolidado por produto (soma das cores). Criado zerado;
        # populado pela importacao do sistema atual. A manutencao automatica
        # (function nova) fica para uma etapa posterior.
        t.decimal :qtd_fiscal, precision: 18, scale: 2, default: "0.0", null: false,
                  comment: "estoque fiscal total do produto (consolida todas as cores)"

        t.boolean :ativo, default: true, null: false
        t.timestamps
      end

      # Um registro fiscal por empresa+produto.
      add_index :fiscal_produto, [:cod_empresa, :cod_produto], unique: true,
                name: "idx_fiscal_produto_empresa_produto"
      # Busca por perfil (ex.: listar produtos de um perfil).
      add_index :fiscal_produto, :cod_perfil_tributario,
                name: "idx_fiscal_produto_perfil"
    end
  end
end
