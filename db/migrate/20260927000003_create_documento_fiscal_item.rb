class CreateDocumentoFiscalItem < ActiveRecord::Migration[7.1]
  # Itens de um DocumentoFiscal, PERSISTIDOS, para permitir editar a nota antes
  # de emitir (rascunho editavel). Antes os itens da nota avulsa eram efemeros
  # (so em memoria; apos autorizar viviam so no XML). Agora a nota em elaboracao
  # (status rascunho) guarda seus itens aqui.
  #
  # Vale para avulsa (documento com cod_venda nil) e para NF de venda (documento
  # com cod_venda preenchido) editada antes de emitir. O item e sempre de um
  # produto CADASTRADO (cod_produto obrigatorio). nome_produto e um snapshot.
  # NCM/CFOP/CSOSN da emissao continuam resolvidos por FiscalProduto/regra do
  # perfil no momento de emitir; cfop/cod_perfil_tributario aqui sao overrides
  # escolhidos na tela (como ja ocorre na avulsa).
  def change
    unless table_exists?(:documento_fiscal_item)
      create_table :documento_fiscal_item, primary_key: :cod_documento_fiscal_item do |t|
        t.bigint  :cod_documento_fiscal, null: false, comment: "FK cabecalho (documento_fiscal)"
        t.bigint  :cod_produto, null: false, comment: "produto cadastrado"
        t.bigint  :cod_cor,                comment: "cor (empresaproduto)"
        t.string  :nome_produto, limit: 120, comment: "snapshot do nome na edicao"
        t.decimal :quantidade,    precision: 18, scale: 2, default: "0.0", null: false
        t.decimal :valorunitario, precision: 18, scale: 2, default: "0.0", null: false
        t.decimal :valor_total,   precision: 18, scale: 2, default: "0.0", null: false
        t.bigint  :cod_perfil_tributario, comment: "perfil override (opcional)"
        t.bigint  :cfop,                  comment: "CFOP override (opcional)"
        t.integer :ordem, default: 0,     comment: "ordem na nota"
        t.timestamps
      end

      add_index :documento_fiscal_item, :cod_documento_fiscal,
                name: "idx_doc_fiscal_item_documento"
    end
  end
end
