class CreateTabelasFiscais < ActiveRecord::Migration[7.1]
  def change
    # ============================================================
    # PERFIL TRIBUTARIO
    # Cadastro reutilizavel. Muitos produtos apontam para o mesmo perfil.
    # Nao contem CSOSN/CFOP: a tributacao fica nas regras.
    # ============================================================
    unless table_exists?(:perfil_tributario)
      create_table :perfil_tributario, primary_key: :cod_perfil_tributario do |t|
        t.string  :nome,      limit: 100, null: false
        t.string  :descricao, limit: 255
        t.boolean :ativo,     default: true, null: false
        t.timestamps
      end
      add_index :perfil_tributario, :ativo, name: "idx_perfil_tributario_ativo"
    end

    # ============================================================
    # OPERACAO FISCAL
    # Tipo de movimento: Venda, Devolucao de venda, Devolucao de compra,
    # Transferencia, NF avulsa... Define natureza + modelo tipico (55/65).
    # ============================================================
    unless table_exists?(:operacao_fiscal)
      create_table :operacao_fiscal, primary_key: :cod_operacao_fiscal do |t|
        t.string  :nome,              limit: 60, null: false, comment: "Venda, Devolucao venda, NF avulsa..."
        t.string  :tipo,              limit: 10, null: false, comment: "saida / entrada"
        t.integer :modelo,            comment: "55 ou 65 (opcional)"
        t.string  :natureza_operacao, limit: 60, comment: "texto que vai na nota"
        t.boolean :ativo,             default: true, null: false
        t.timestamps
      end
      add_index :operacao_fiscal, :ativo, name: "idx_operacao_fiscal_ativo"
    end

    # ============================================================
    # REGRA FISCAL (o coracao)
    # Resolve a tributacao pelo contexto:
    # (empresa/regime + perfil + operacao + uf_destino + tipo_cliente)
    #   -> cfop_base, csosn, aliquotas, cclasstrib
    # cfop_base = 3 digitos (ex "102"); o 5/6/7 e resolvido na emissao.
    # uf_destino e tipo_cliente aceitam "*" (curinga) para a regra padrao.
    # prioridade: maior vence quando ha padrao (*) + excecao especifica.
    # ============================================================
    unless table_exists?(:regra_fiscal)
      create_table :regra_fiscal, primary_key: :cod_regra_fiscal do |t|
        t.bigint  :cod_perfil_tributario, null: false
        t.bigint  :cod_operacao_fiscal,   null: false
        t.bigint  :cod_empresa,           null: false, comment: "regime/estabelecimento emitente"

        t.string  :uf_destino,   limit: 2,  default: "*", null: false, comment: "sigla UF ou * (todas)"
        t.string  :tipo_cliente, limit: 20, default: "*", null: false, comment: "consumidor_final / contribuinte / *"

        t.string  :cfop_base,    limit: 4,  null: false, comment: "3 digitos base, ex 102 (5/6/7 automatico)"
        t.string  :csosn,        limit: 4,  comment: "CSOSN no Simples"
        t.decimal :aliquota_icms, precision: 6, scale: 2, comment: "opcional"
        t.string  :cst_pis,      limit: 3
        t.string  :cst_cofins,   limit: 3
        t.string  :cclasstrib,   limit: 10, comment: "IBS/CBS reforma (vazio por ora)"

        t.integer :prioridade,   default: 0, null: false, comment: "maior vence: excecao > padrao"
        t.boolean :ativo,        default: true, null: false
        t.timestamps
      end

      add_index :regra_fiscal,
                [:cod_empresa, :cod_perfil_tributario, :cod_operacao_fiscal, :uf_destino, :tipo_cliente],
                name: "idx_regra_fiscal_resolucao"
      add_index :regra_fiscal, :cod_perfil_tributario, name: "idx_regra_fiscal_perfil"
      add_index :regra_fiscal, :cod_operacao_fiscal,   name: "idx_regra_fiscal_operacao"
    end
  end
end
