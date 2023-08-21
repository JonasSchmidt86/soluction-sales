# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_03_29_144607) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "acertosestoque", id: false, force: :cascade do |t|
    t.bigint "codigo", default: -> { "nextval('acertoestoque_codigo_seq'::regclass)" }, null: false
    t.string "descricao", limit: 200
    t.string "tipo", limit: 1, null: false
    t.bigint "cod_cor", null: false
    t.bigint "cod_produto", null: false
    t.decimal "quantidade", precision: 18, scale: 2, default: "0.0"
    t.datetime "datacadastro"
    t.bigint "cod_empresa", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assistencia", id: false, force: :cascade do |t|
    t.bigint "codigo", null: false
    t.date "datadevolucao"
    t.date "dataenvio"
    t.string "descricaoproblema", limit: 255
    t.string "numerosolicitacao", limit: 255
    t.bigint "cod_pessoa", null: false
    t.bigint "cod_produto", null: false
    t.bigint "cod_empresa", null: false
    t.bigint "cod_funcionario", null: false
  end

  create_table "banco", id: false, force: :cascade do |t|
    t.bigint "cod_banco", null: false
    t.string "nomebanco", limit: 255
    t.string "telefone", limit: 255
  end

  create_table "bancocheques", id: false, force: :cascade do |t|
    t.bigint "cod_dadoscheque", null: false
    t.date "dataemissao"
    t.date "diavencimento"
    t.string "numerocheque", limit: 255
    t.decimal "valor", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_banco"
    t.bigint "cod_contaspagrec"
    t.bigint "cod_empresa"
    t.bigint "lancamentos_cod_empresa"
    t.bigint "lancamentos_cod_funcionario"
    t.bigint "lancamentos_cod_lancamentocaixa"
    t.bigint "tipolancamento_cod_tppagamento"
    t.bigint "cod_dono"
    t.bigint "cod_emissor"
  end

  create_table "bancoconta", id: false, force: :cascade do |t|
    t.bigint "cod_bancoconta", null: false
    t.string "agencia", limit: 255
    t.bigint "cod_empresa"
    t.string "contacorrente", limit: 255
    t.bigint "cod_banco"
    t.boolean "ativo"
    t.float "entradas"
    t.float "saidas"
    t.bigint "cod_pessoa"
    t.boolean "interno", default: false, null: false, comment: "interno - aparece apenas na empresa logada empresa logada"
  end

  create_table "cadinternalframes", id: false, force: :cascade do |t|
    t.bigint "cod_frame", null: false
    t.string "jmenu", limit: 100, null: false
    t.string "nminternalframe", limit: 100, null: false
    t.integer "tamanhomenu"
    t.string "tituloframe", limit: 100, null: false
  end

  create_table "caixa", id: false, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
    t.datetime "dataabertura", null: false
    t.datetime "datafechamento"
    t.decimal "valorabertura", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorentradas", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorfechamento", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorsaidas", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_funcionarioabertura", null: false
    t.bigint "cod_funcionariofechamento"
    t.serial "id", null: false
  end

  create_table "cidade", id: false, force: :cascade do |t|
    t.bigint "cod_cidade", null: false
    t.string "nome", limit: 255
    t.bigint "cod_estado"
    t.bigint "cod_municipio"
  end

  create_table "collaborators", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "cod_funcionario"
    t.bigint "cod_empresa"
    t.index ["email"], name: "index_collaborators_on_email", unique: true
    t.index ["reset_password_token"], name: "index_collaborators_on_reset_password_token", unique: true
  end

  create_table "compra", id: false, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
    t.boolean "cancelada"
    t.bigint "cod_frete"
    t.datetime "datacancelamento"
    t.datetime "datacompra"
    t.date "dataemissao"
    t.string "numeronf", limit: 255
    t.string "serienf", limit: 255
    t.decimal "valorfrete", precision: 18, scale: 2, default: "0.0"
    t.decimal "valortotal", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_funcionario", null: false
    t.bigint "cod_compraempresa"
    t.bigserial "cod_compra", null: false
    t.bigint "cod_pessoa"
    t.string "arquivoxml", limit: 100
    t.decimal "desconto", precision: 18, scale: 3, default: "0.0"
    t.decimal "outrasdespesas", precision: 18, scale: 3, default: "0.0"
  end

  create_table "contaspagrec", id: false, force: :cascade do |t|
    t.bigint "cod_contaspagrec", null: false
    t.bigint "cod_empresa", null: false
    t.boolean "ativo"
    t.bigint "cod_compra"
    t.bigint "cod_frete"
    t.bigint "cod_venda"
    t.date "dtvencimento"
    t.integer "numeroparcela"
    t.boolean "quitada"
    t.decimal "valorparcela", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_tppagamento"
  end

  create_table "cores", id: false, force: :cascade do |t|
    t.bigint "cod_cor", null: false
    t.boolean "ativo"
    t.string "nmcor", limit: 100
  end

  create_table "empresa", id: false, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
    t.boolean "ativo"
    t.string "cpf_cnpj", limit: 14
    t.string "endereco", limit: 150
    t.string "inscricaoestadual", limit: 15
    t.string "logotipo", limit: 50
    t.string "nome", limit: 100
    t.string "numero", limit: 15
    t.bigint "cod_cidade"
    t.bigint "cod_parametroempresa"
    t.bigint "cod_bancoconta"
    t.bigint "cod_pessoa"
  end

  create_table "empresaproduto", id: false, force: :cascade do |t|
    t.bigint "cod_cor", null: false
    t.bigint "cod_empresa", null: false
    t.bigint "cod_produto", null: false
    t.decimal "customedio", precision: 18, scale: 2, default: "0.0"
    t.decimal "quantidade", precision: 18, scale: 2, default: "0.0"
    t.decimal "quantidademinima", precision: 18, scale: 2, default: "0.0"
    t.decimal "ultimocusto", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorvenda", precision: 18, scale: 2, default: "0.0"
    t.date "dataalteracao"
    t.decimal "qtdfiscal", precision: 18, scale: 2, default: "0.0"
    t.string "cest", limit: 15
    t.serial "id", null: false
    t.boolean "ativo", default: true
  end

  create_table "entrega", id: false, force: :cascade do |t|
    t.bigint "cod_entrega", default: -> { "nextval('entrega_codigo_seq'::regclass)" }, null: false
    t.boolean "assistencia", default: false, null: false
    t.datetime "dataassistencia", comment: "DATA DE SOLICITACAO DE PEÇAS"
    t.datetime "dataentrega"
    t.boolean "entregue", default: false, null: false
    t.string "observacao", limit: 255
    t.bigint "cod_venda", null: false
  end

  create_table "estado", id: false, force: :cascade do |t|
    t.bigint "cod_estado", null: false
    t.string "nomeestado", limit: 255
    t.string "sigla", limit: 2
    t.bigint "cod_estado_ibge"
  end

  create_table "formaspagamento", id: false, force: :cascade do |t|
    t.bigint "cod_formaspagamento", null: false
    t.decimal "acrescimo", precision: 18, scale: 2, default: "0.0"
    t.boolean "ativo"
    t.date "datacadastro"
    t.date "dataupdate"
    t.decimal "desconto", precision: 18, scale: 2, default: "0.0"
    t.string "descricao", limit: 50, null: false
    t.boolean "entrada"
    t.integer "intervalodias"
    t.integer "numeroparcalas"
    t.date "validade"
  end

  create_table "framefuncionario", id: false, force: :cascade do |t|
    t.bigint "cod_frame", null: false
    t.bigint "cod_funcionarioempresa", null: false
    t.boolean "excluir"
    t.boolean "grava"
    t.boolean "localizar"
    t.boolean "menulateral"
    t.integer "nrdiasbuscas"
    t.integer "nrmesbuscas"
    t.integer "sequencelateral"
    t.boolean "vercustos"
  end

  create_table "frete", id: false, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
    t.bigint "cod_frete", null: false
    t.boolean "ativo"
    t.date "datacadastro"
    t.date "datavencimento"
    t.decimal "valor", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_pessoa"
    t.decimal "nrromaneio"
  end

  create_table "funcionario", id: false, force: :cascade do |t|
    t.bigint "cod_funcionario", null: false
    t.boolean "ativo"
    t.date "datacontrato"
    t.date "datademissao"
    t.decimal "salario", precision: 18, scale: 2, default: "0.0"
    t.string "senha", limit: 15
    t.string "usuario", limit: 50
    t.bigint "cod_permissao"
    t.bigint "cod_pessoa"
  end

  create_table "funcionarioempresa", id: false, force: :cascade do |t|
    t.bigint "cod_funcionarioempresa", null: false
    t.boolean "ativo"
    t.bigint "cod_empresa"
    t.bigint "cod_funcionario", null: false
  end

  create_table "grupo", id: false, force: :cascade do |t|
    t.bigint "cod_grupo", null: false
    t.string "nomegrupo", limit: 100
    t.bigint "cod_margem"
  end

  create_table "imagem", id: false, force: :cascade do |t|
    t.bigint "cod_image", null: false
    t.binary "imgproduto", null: false
    t.string "nome", limit: 50
    t.integer "version", null: false
    t.bigint "produto"
  end

  create_table "itemcompra", id: false, force: :cascade do |t|
    t.bigint "cod_item", null: false
    t.bigint "cod_compra"
    t.bigint "cod_empresa", null: false
    t.bigint "cod_produto"
    t.decimal "icms", precision: 18, scale: 2, default: "0.0"
    t.decimal "ipi", precision: 18, scale: 2, default: "0.0"
    t.bigint "numeronf"
    t.decimal "quantidade", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorst", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorunitario", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_cor"
    t.boolean "cancelado", default: false, null: false
  end

  create_table "itemvenda", id: false, force: :cascade do |t|
    t.bigint "cod_item", null: false
    t.bigint "cod_empresa", null: false
    t.bigint "cod_produto"
    t.bigint "cod_venda"
    t.bigint "numeronf"
    t.decimal "quantidade", precision: 18, scale: 2, default: "0.0"
    t.decimal "valorunitario", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_cor"
    t.boolean "cancelado", default: false, null: false
    t.boolean "aceita", default: false, comment: "criado para o usuario aceitar a transferencia, ou para conferencia evitar erros, se true esta conferido e aceito pelo usuario"
    t.decimal "valororiginal", precision: 18, scale: 2, default: "0.0"
  end

  create_table "lancamentoscaixa", id: false, force: :cascade do |t|
    t.string "tipo", limit: 1, null: false
    t.bigint "cod_empresa", null: false
    t.bigint "cod_funcionario", null: false
    t.bigint "cod_lancamentocaixa", null: false
    t.boolean "cancelada"
    t.bigint "cod_contaspagrec"
    t.datetime "dataabertura"
    t.datetime "datamodificacao"
    t.datetime "datapagto"
    t.decimal "valor", precision: 18, scale: 2, default: "0.0", null: false
    t.bigint "cod_dadoscheque"
    t.bigint "cod_bancoconta"
    t.bigint "cod_tphitorico"
    t.bigint "cod_lancamentodiverso"
    t.string "descricao", limit: 100
    t.bigint "cod_pessoa"
    t.bigint "cod_bancocontadestino"
    t.bigint "caixa_id"
  end

  create_table "lancamentosdiversos", id: false, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
    t.bigint "cod_lancamento", null: false
    t.date "datainicio"
    t.date "datavencimento"
    t.string "descricao", limit: 50, null: false
    t.boolean "entrada"
    t.integer "enumprovisionado"
    t.boolean "provisionada"
    t.decimal "valor", precision: 18, scale: 2, default: "0.0", null: false
    t.bigint "cod_funcionario"
    t.bigint "cod_tphitorico"
  end

  create_table "lembretes", id: false, force: :cascade do |t|
    t.bigint "codigo", null: false
    t.boolean "ativo"
    t.date "datacadastro"
    t.string "descricao", limit: 255
    t.bigint "cod_empresa"
    t.bigint "cod_empresasolicitada"
    t.bigint "cod_funcionario"
  end

  create_table "marca", id: false, force: :cascade do |t|
    t.bigint "cod_marca", null: false
    t.string "nome", limit: 200
  end

  create_table "parametros", id: false, force: :cascade do |t|
    t.bigint "cod_parametro", null: false
    t.boolean "ativo", null: false
    t.date "dataencerramento"
    t.string "descricao", limit: 40
    t.decimal "margemproduto", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_empresa"
  end

  create_table "parametrosempresa", id: false, force: :cascade do |t|
    t.bigint "cod_parametroempresa", null: false
    t.boolean "imprimenota"
    t.boolean "imprimepromissoria"
    t.boolean "imprimerecibo"
    t.boolean "imprimerelatoriocaixa"
    t.boolean "maiusculo"
    t.boolean "etiqueta", default: false
  end

  create_table "permissao", id: false, force: :cascade do |t|
    t.bigint "cod_permissao", null: false
    t.string "descricao", limit: 50
    t.integer "nivel"
  end

  create_table "pessoa", id: false, force: :cascade do |t|
    t.string "tipo", limit: 1, null: false
    t.string "cpf_cnpj", limit: 20, null: false
    t.string "apelido", limit: 100
    t.string "bairro", limit: 100
    t.string "celular", limit: 20
    t.string "cep", limit: 10
    t.string "complemento", limit: 100
    t.date "datacadastro"
    t.string "endereco", limit: 100
    t.string "nome", limit: 150, null: false
    t.string "numero", limit: 15
    t.string "rg_ie", limit: 20
    t.string "telefone", limit: 20
    t.integer "civil"
    t.string "cpfconj", limit: 14
    t.date "dtnascimento"
    t.date "dtnascimentoconj"
    t.string "emprego", limit: 150
    t.string "nomeconj", limit: 150
    t.string "rgconjuge", limit: 15
    t.float "salario"
    t.string "pessoacontato", limit: 15
    t.string "telefonecontato", limit: 100
    t.bigint "cod_cidade"
    t.decimal "credito", precision: 18, scale: 2, default: "0.0"
    t.serial "cod_pessoa", null: false
    t.bigint "nrcadpro"
    t.date "dtconsulta"
    t.boolean "registradoscpc"
    t.string "email", limit: 100
  end

  create_table "produto", id: false, force: :cascade do |t|
    t.bigint "cod_produto", null: false
    t.string "nome", limit: 100
    t.bigint "grupo", default: 1, comment: "margem padrao moveis"
    t.bigint "marca"
    t.bigint "cod_margem"
    t.decimal "custo", precision: 18, scale: 2, default: "0.0"
    t.string "ncm", limit: 15
    t.string "ucom", limit: 8
    t.bigint "cfop"
    t.boolean "ativo", default: true, null: false
    t.string "cest", limit: 15
  end

  create_table "produtoxml", id: false, force: :cascade do |t|
    t.bigint "codigo", null: false
    t.string "codproemissor", limit: 50
    t.string "nome", limit: 200
    t.bigint "cod_cor", null: false
    t.bigint "cod_produto", null: false
    t.string "infadicionais", limit: 500
    t.string "ncm", limit: 15
    t.bigint "cod_pessoa"
    t.string "ucom", limit: 8
    t.bigint "cfop"
    t.string "cest", limit: 15
  end

  create_table "tiposhistoricoscaixa", id: false, force: :cascade do |t|
    t.bigint "cod_tphitorico", null: false
    t.boolean "ativo"
    t.string "descricao", limit: 100
  end

  create_table "tiposlancamento", id: false, force: :cascade do |t|
    t.bigint "cod_tppagamento", null: false
    t.boolean "ativo"
    t.boolean "cadastracheque"
    t.bigint "cod_empresa"
    t.float "custo"
    t.boolean "debitoautomatico"
    t.date "dtcadastro"
    t.boolean "entrada"
    t.string "nometipo", limit: 255
    t.boolean "vaibanco"
    t.boolean "vaicaixa"
    t.bigint "cod_banco"
    t.bigint "cod_bancoconta"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "venda", id: false, force: :cascade do |t|
    t.string "tipo", limit: 1, null: false
    t.bigint "cod_empresa", null: false
    t.boolean "cancelada"
    t.datetime "datanf"
    t.datetime "datavenda"
    t.bigint "numeronf"
    t.decimal "valortotal", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_frete"
    t.bigint "cod_funcionario", null: false
    t.bigint "cod_empresa_transferida"
    t.bigint "cod_vendaempresa"
    t.bigserial "cod_venda", null: false
    t.bigint "cod_pessoa"
    t.decimal "acrescimo", precision: 18, scale: 3, default: "0.0"
    t.decimal "desconto", precision: 18, scale: 3, default: "0.0"
    t.boolean "aceita", default: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
