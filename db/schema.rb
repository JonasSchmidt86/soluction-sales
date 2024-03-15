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

ActiveRecord::Schema.define(version: 2024_01_26_163520) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "plpgsql"

  create_table "acertosestoque", primary_key: "codigo", id: :bigint, default: -> { "nextval('acertoestoque_codigo_seq'::regclass)" }, force: :cascade do |t|
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

  create_table "assistencia", primary_key: "codigo", id: :bigint, default: nil, force: :cascade do |t|
    t.date "datadevolucao"
    t.date "dataenvio"
    t.string "descricaoproblema", limit: 255
    t.string "numerosolicitacao", limit: 255
    t.bigint "cod_pessoa", null: false
    t.bigint "cod_produto", null: false
    t.bigint "cod_empresa", null: false
    t.bigint "cod_funcionario", null: false
  end

  create_table "banco", primary_key: "cod_banco", id: :bigint, default: nil, force: :cascade do |t|
    t.string "nomebanco", limit: 255
    t.string "telefone", limit: 255
  end

  create_table "bancocheques", primary_key: "cod_dadoscheque", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "bancoconta", primary_key: "cod_bancoconta", id: :bigint, default: nil, force: :cascade do |t|
    t.string "agencia", limit: 255
    t.bigint "cod_empresa"
    t.string "contacorrente", limit: 255
    t.bigint "cod_banco"
    t.boolean "ativo"
    t.float "entradas"
    t.float "saidas"
    t.bigint "cod_pessoa"
    t.boolean "interno", default: false, null: false, comment: "interno - aparece apenas na empresa logada empresa logada"
    t.index ["cod_pessoa"], name: "fkb_pessoa"
  end

  create_table "cadinternalframes", primary_key: "cod_frame", id: :bigint, default: nil, force: :cascade do |t|
    t.string "jmenu", limit: 100, null: false
    t.string "nminternalframe", limit: 100, null: false
    t.integer "tamanhomenu"
    t.string "tituloframe", limit: 100, null: false
  end

  create_table "caixa", primary_key: ["cod_empresa", "dataabertura"], force: :cascade do |t|
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

  create_table "cidade", primary_key: "cod_cidade", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "compra", primary_key: "cod_compra", force: :cascade do |t|
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
    t.bigint "cod_pessoa"
    t.string "arquivoxml", limit: 100
    t.decimal "desconto", precision: 18, scale: 3, default: "0.0"
    t.decimal "outrasdespesas", precision: 18, scale: 3, default: "0.0"
    t.index ["cod_pessoa"], name: "fki_pessoa"
  end

  create_table "contaspagrec", primary_key: "cod_contaspagrec", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "cores", primary_key: "cod_cor", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "ativo"
    t.string "nmcor", limit: 100
  end

  create_table "empresa", primary_key: "cod_empresa", id: :bigint, default: nil, force: :cascade do |t|
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
    t.index ["cod_pessoa"], name: "fke_pessoa"
  end

  create_table "empresaproduto", primary_key: ["cod_cor", "cod_empresa", "cod_produto"], force: :cascade do |t|
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

  create_table "entrega", primary_key: "cod_entrega", id: :bigint, default: -> { "nextval('entrega_codigo_seq'::regclass)" }, force: :cascade do |t|
    t.boolean "assistencia", default: false, null: false
    t.datetime "dataassistencia", comment: "DATA DE SOLICITACAO DE PEÇAS"
    t.datetime "dataentrega"
    t.boolean "entregue", default: false, null: false
    t.string "observacao", limit: 255
    t.bigint "cod_venda", null: false
  end

  create_table "estado", primary_key: "cod_estado", id: :bigint, default: nil, force: :cascade do |t|
    t.string "nomeestado", limit: 255
    t.string "sigla", limit: 2
    t.bigint "cod_estado_ibge"
  end

  create_table "formaspagamento", primary_key: "cod_formaspagamento", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "framefuncionario", primary_key: ["cod_frame", "cod_funcionarioempresa"], force: :cascade do |t|
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

  create_table "frete", primary_key: "cod_frete", id: :bigint, default: nil, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
    t.boolean "ativo"
    t.date "datacadastro"
    t.date "datavencimento"
    t.decimal "valor", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_pessoa"
    t.decimal "nrromaneio"
    t.index ["cod_pessoa"], name: "fkfe_pessoa"
  end

  create_table "funcionario", primary_key: "cod_funcionario", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "ativo"
    t.date "datacontrato"
    t.date "datademissao"
    t.decimal "salario", precision: 18, scale: 2, default: "0.0"
    t.string "senha", limit: 15
    t.string "usuario", limit: 50
    t.bigint "cod_permissao"
    t.bigint "cod_pessoa"
    t.index ["cod_pessoa"], name: "fkfu_pessoa"
  end

  create_table "funcionarioempresa", primary_key: "cod_funcionarioempresa", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "ativo"
    t.bigint "cod_empresa"
    t.bigint "cod_funcionario", null: false
  end

  create_table "grupo", primary_key: "cod_grupo", id: :bigint, default: nil, force: :cascade do |t|
    t.string "nomegrupo", limit: 100
    t.bigint "cod_margem"
  end

  create_table "imagem", primary_key: "cod_image", id: :bigint, default: nil, force: :cascade do |t|
    t.binary "imgproduto", null: false
    t.string "nome", limit: 50
    t.integer "version", null: false
    t.bigint "produto"
  end

  create_table "itemcompra", primary_key: "cod_item", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "itemvenda", primary_key: "cod_item", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "lancamentoscaixa", primary_key: "cod_lancamentocaixa", id: :bigint, default: nil, force: :cascade do |t|
    t.string "tipo", limit: 1, null: false
    t.bigint "cod_empresa", null: false
    t.bigint "cod_funcionario", null: false
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
    t.index ["cod_bancocontadestino"], name: "fk_bancocontadestino"
    t.index ["cod_pessoa"], name: "fkl_pessoa"
  end

  create_table "lancamentosdiversos", primary_key: "cod_lancamento", id: :bigint, default: nil, force: :cascade do |t|
    t.bigint "cod_empresa", null: false
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

  create_table "lembretes", primary_key: "codigo", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "ativo"
    t.date "datacadastro"
    t.string "descricao", limit: 255
    t.bigint "cod_empresa"
    t.bigint "cod_empresasolicitada"
    t.bigint "cod_funcionario"
  end

  create_table "marca", primary_key: "cod_marca", id: :bigint, default: nil, force: :cascade do |t|
    t.string "nome", limit: 200
  end

  create_table "parametros", primary_key: "cod_parametro", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "ativo", null: false
    t.date "dataencerramento"
    t.string "descricao", limit: 40
    t.decimal "margemproduto", precision: 18, scale: 2, default: "0.0"
    t.bigint "cod_empresa"
  end

  create_table "parametrosempresa", primary_key: "cod_parametroempresa", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "imprimenota"
    t.boolean "imprimepromissoria"
    t.boolean "imprimerecibo"
    t.boolean "imprimerelatoriocaixa"
    t.boolean "maiusculo"
    t.boolean "etiqueta", default: false
  end

  create_table "permissao", primary_key: "cod_permissao", id: :bigint, default: nil, force: :cascade do |t|
    t.string "descricao", limit: 50
    t.integer "nivel"
  end

  create_table "pessoa", primary_key: "cod_pessoa", id: :serial, force: :cascade do |t|
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
    t.bigint "nrcadpro"
    t.date "dtconsulta"
    t.boolean "registradoscpc"
    t.string "email", limit: 100
    t.index ["cpf_cnpj"], name: "uni_cpf_cnpj", unique: true
  end

  create_table "produto", primary_key: "cod_produto", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "produtoxml", primary_key: "codigo", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "tiposhistoricoscaixa", primary_key: "cod_tphitorico", id: :bigint, default: nil, force: :cascade do |t|
    t.boolean "ativo"
    t.string "descricao", limit: 100
  end

  create_table "tiposlancamento", primary_key: "cod_tppagamento", id: :bigint, default: nil, force: :cascade do |t|
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

  create_table "venda", primary_key: "cod_venda", force: :cascade do |t|
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
    t.bigint "cod_pessoa"
    t.decimal "acrescimo", precision: 18, scale: 3, default: "0.0"
    t.decimal "desconto", precision: 18, scale: 3, default: "0.0"
    t.boolean "aceita", default: false
    t.index ["cod_pessoa"], name: "fkv_pessoa"
  end

  create_table "xml_files", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "name"
    t.bigint "pessoa_id"
    t.bigint "empresa_id"
    t.index ["empresa_id"], name: "index_xml_files_on_empresa_id"
    t.index ["pessoa_id"], name: "index_xml_files_on_pessoa_id"
  end

  add_foreign_key "acertosestoque", "cores", column: "cod_cor", primary_key: "cod_cor", name: "fk_cor"
  add_foreign_key "acertosestoque", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "acertosestoque", "produto", column: "cod_produto", primary_key: "cod_produto", name: "fk_produto"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assistencia", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "assistencia", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "pk_funcionario"
  add_foreign_key "assistencia", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "assistencia", "produto", column: "cod_produto", primary_key: "cod_produto", name: "fk_produto"
  add_foreign_key "bancocheques", "banco", column: "cod_banco", primary_key: "cod_banco", name: "fk_banco"
  add_foreign_key "bancocheques", "contaspagrec", column: "cod_contaspagrec", primary_key: "cod_contaspagrec", name: "fk_contaspagrec"
  add_foreign_key "bancocheques", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "bancocheques", "lancamentoscaixa", column: "lancamentos_cod_lancamentocaixa", primary_key: "cod_lancamentocaixa", name: "fk_lancamentocaixa"
  add_foreign_key "bancocheques", "pessoa", column: "cod_dono", primary_key: "cod_pessoa", name: "fk_donocheque"
  add_foreign_key "bancocheques", "pessoa", column: "cod_emissor", primary_key: "cod_pessoa", name: "fk_emissorcheque"
  add_foreign_key "bancocheques", "tiposlancamento", column: "tipolancamento_cod_tppagamento", primary_key: "cod_tppagamento", name: "fk_tipolancamento"
  add_foreign_key "bancoconta", "banco", column: "cod_banco", primary_key: "cod_banco", name: "fk_banco"
  add_foreign_key "bancoconta", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "bancoconta", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "caixa", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk3ddd7d43eac1b66"
  add_foreign_key "caixa", "funcionario", column: "cod_funcionarioabertura", primary_key: "cod_funcionario", name: "fk3ddd7d4ee46d608"
  add_foreign_key "caixa", "funcionario", column: "cod_funcionariofechamento", primary_key: "cod_funcionario", name: "fk3ddd7d4cdb9987e"
  add_foreign_key "cidade", "estado", column: "cod_estado", primary_key: "cod_estado", name: "fk784b43443c803df8"
  add_foreign_key "compra", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk78a4219e3eac1b66"
  add_foreign_key "compra", "frete", column: "cod_frete", primary_key: "cod_frete", name: "fk_frete"
  add_foreign_key "compra", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "fk78a4219e17048c0a"
  add_foreign_key "compra", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "contaspagrec", "compra", column: "cod_compra", primary_key: "cod_compra", name: "fk_compra"
  add_foreign_key "contaspagrec", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "contaspagrec", "frete", column: "cod_frete", primary_key: "cod_frete", name: "fk_frete"
  add_foreign_key "contaspagrec", "tiposlancamento", column: "cod_tppagamento", primary_key: "cod_tppagamento", name: "fk_tppagto"
  add_foreign_key "contaspagrec", "venda", column: "cod_venda", primary_key: "cod_venda", name: "fk_venda"
  add_foreign_key "empresa", "bancoconta", column: "cod_bancoconta", primary_key: "cod_bancoconta", name: "fk_bancoconta"
  add_foreign_key "empresa", "cidade", column: "cod_cidade", primary_key: "cod_cidade", name: "fk_cidade"
  add_foreign_key "empresa", "parametrosempresa", column: "cod_parametroempresa", primary_key: "cod_parametroempresa", name: "fk_parametrosemp"
  add_foreign_key "empresa", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "empresaproduto", "cores", column: "cod_cor", primary_key: "cod_cor", name: "fk_cor"
  add_foreign_key "empresaproduto", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_produtosempresa"
  add_foreign_key "empresaproduto", "produto", column: "cod_produto", primary_key: "cod_produto", name: "fk_produtos"
  add_foreign_key "entrega", "venda", column: "cod_venda", primary_key: "cod_venda", name: "fk_venda"
  add_foreign_key "framefuncionario", "cadinternalframes", column: "cod_frame", primary_key: "cod_frame", name: "fk_internalframe"
  add_foreign_key "framefuncionario", "funcionarioempresa", column: "cod_funcionarioempresa", primary_key: "cod_funcionarioempresa", name: "fk912b2a4e9174cda8"
  add_foreign_key "frete", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "frete", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "funcionario", "permissao", column: "cod_permissao", primary_key: "cod_permissao", name: "fk_permissao"
  add_foreign_key "funcionario", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "funcionarioempresa", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "pk_empresa"
  add_foreign_key "funcionarioempresa", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "fk_funcionarioempresas"
  add_foreign_key "grupo", "parametros", column: "cod_margem", primary_key: "cod_parametro", name: "fk41e1c499ecb7837"
  add_foreign_key "imagem", "produto", column: "produto", primary_key: "cod_produto", name: "fk82bf6e92e3c9080d"
  add_foreign_key "itemcompra", "compra", column: "cod_compra", primary_key: "cod_compra", name: "fk_compra"
  add_foreign_key "itemcompra", "cores", column: "cod_cor", primary_key: "cod_cor", name: "fk_cor"
  add_foreign_key "itemcompra", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "itemcompra", "produto", column: "cod_produto", primary_key: "cod_produto", name: "fk_produto"
  add_foreign_key "itemvenda", "cores", column: "cod_cor", primary_key: "cod_cor", name: "fk_cor"
  add_foreign_key "itemvenda", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "itemvenda", "produto", column: "cod_produto", primary_key: "cod_produto", name: "fk_produto"
  add_foreign_key "itemvenda", "venda", column: "cod_venda", primary_key: "cod_venda", name: "fk_venda"
  add_foreign_key "lancamentoscaixa", "bancocheques", column: "cod_dadoscheque", primary_key: "cod_dadoscheque", name: "fk_bancocheque"
  add_foreign_key "lancamentoscaixa", "bancoconta", column: "cod_bancoconta", primary_key: "cod_bancoconta", name: "fk_bancoconta"
  add_foreign_key "lancamentoscaixa", "bancoconta", column: "cod_bancocontadestino", primary_key: "cod_bancoconta", name: "fk_bancocontadestino"
  add_foreign_key "lancamentoscaixa", "caixa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_caixa"
  add_foreign_key "lancamentoscaixa", "contaspagrec", column: "cod_contaspagrec", primary_key: "cod_contaspagrec", name: "fk_contaspagrec"
  add_foreign_key "lancamentoscaixa", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "lancamentoscaixa", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "fk_funcionario"
  add_foreign_key "lancamentoscaixa", "lancamentosdiversos", column: "cod_lancamentodiverso", primary_key: "cod_lancamento", name: "fk_lancamentosdiversos"
  add_foreign_key "lancamentoscaixa", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "lancamentoscaixa", "tiposhistoricoscaixa", column: "cod_tphitorico", primary_key: "cod_tphitorico", name: "fk_tipohistocaixa"
  add_foreign_key "lancamentosdiversos", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "lancamentosdiversos", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "lancamentosdiversos_cod_funcionario_fkey"
  add_foreign_key "lancamentosdiversos", "tiposhistoricoscaixa", column: "cod_tphitorico", primary_key: "cod_tphitorico", name: "fk_tphistorico"
  add_foreign_key "lembretes", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "lembretes", "empresa", column: "cod_empresasolicitada", primary_key: "cod_empresa", name: "fk_empresasolicitada"
  add_foreign_key "lembretes", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "pk_funcionario"
  add_foreign_key "parametros", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk9229ce7a3eac1b66"
  add_foreign_key "pessoa", "cidade", column: "cod_cidade", primary_key: "cod_cidade", name: "fk_cidade"
  add_foreign_key "produto", "grupo", column: "grupo", primary_key: "cod_grupo", name: "fk_grupo"
  add_foreign_key "produto", "marca", column: "marca", primary_key: "cod_marca", name: "fk_marca"
  add_foreign_key "produto", "parametros", column: "cod_margem", primary_key: "cod_parametro", name: "fk_parametros"
  add_foreign_key "produtoxml", "cores", column: "cod_cor", primary_key: "cod_cor", name: "fk_cor"
  add_foreign_key "produtoxml", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "produtoxml", "produto", column: "cod_produto", primary_key: "cod_produto", name: "fk_produto"
  add_foreign_key "tiposlancamento", "banco", column: "cod_banco", primary_key: "cod_banco", name: "fk_banco"
  add_foreign_key "tiposlancamento", "bancoconta", column: "cod_bancoconta", primary_key: "cod_bancoconta", name: "fk_bancoconta"
  add_foreign_key "tiposlancamento", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "venda", "empresa", column: "cod_empresa", primary_key: "cod_empresa", name: "fk_empresa"
  add_foreign_key "venda", "empresa", column: "cod_empresa_transferida", primary_key: "cod_empresa", name: "fk_empresa_transferencia"
  add_foreign_key "venda", "frete", column: "cod_frete", primary_key: "cod_frete", name: "fk_frete"
  add_foreign_key "venda", "funcionario", column: "cod_funcionario", primary_key: "cod_funcionario", name: "pk_funcionario"
  add_foreign_key "venda", "pessoa", column: "cod_pessoa", primary_key: "cod_pessoa", name: "fk_pessoa"
  add_foreign_key "xml_files", "empresa", primary_key: "cod_empresa"
  add_foreign_key "xml_files", "pessoa", primary_key: "cod_pessoa"
end
