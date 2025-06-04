class SetDefaultSequenceForCodMarca < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TABLE marca ALTER COLUMN cod_marca SET DEFAULT nextval('marca_codigo_seq');
      ALTER TABLE grupo ALTER COLUMN cod_grupo SET DEFAULT nextval('grupo_codigo_seq');
      ALTER TABLE lancamentosdiversos ALTER COLUMN cod_lancamento SET DEFAULT nextval('lancamentos_diversos_sequence');
      ALTER TABLE assistencia ALTER COLUMN codigo SET DEFAULT nextval('assistencia_codigo_seq');
      ALTER TABLE banco ALTER COLUMN cod_banco SET DEFAULT nextval('banco_codigo_seq');
      ALTER TABLE bancocheques ALTER COLUMN cod_dadoscheque SET DEFAULT nextval('dadoscheque_codigo_seq');
      ALTER TABLE bancoconta ALTER COLUMN cod_bancoconta SET DEFAULT nextval('bancoconta_codigo_seq');
      ALTER TABLE cidade ALTER COLUMN cod_cidade SET DEFAULT nextval('cidade_codigo_seq');
      ALTER TABLE empresa ALTER COLUMN cod_empresa SET DEFAULT nextval('empresa_codigo_seq');
      ALTER TABLE estado ALTER COLUMN cod_estado SET DEFAULT nextval('estado_codigo_seq');
      ALTER TABLE formaspagamento ALTER COLUMN cod_formaspagamento SET DEFAULT nextval('formaspagamento_codigo_seq');
      ALTER TABLE imagem ALTER COLUMN cod_image SET DEFAULT nextval('imagem_codigo_seq');
      ALTER TABLE parametros ALTER COLUMN cod_parametro SET DEFAULT nextval('parametro_codigo_seq');
      ALTER TABLE parametrosempresa ALTER COLUMN cod_parametroempresa SET DEFAULT nextval('parametro_empresa_codigo_seq');
      ALTER TABLE permissao ALTER COLUMN cod_permissao SET DEFAULT nextval('permissao_codigo_seq');
      ALTER TABLE tiposhistoricoscaixa ALTER COLUMN cod_tphitorico SET DEFAULT nextval('tphistorico_codigo_seq');
      ALTER TABLE tiposlancamento ALTER COLUMN cod_tppagamento SET DEFAULT nextval('tiposlancamento_codigo_seq');
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE marca ALTER COLUMN cod_marca DROP DEFAULT;
      ALTER TABLE grupo ALTER COLUMN cod_grupo DROP DEFAULT;
      ALTER TABLE lancamentosdiversos ALTER COLUMN cod_lancamento DROP DEFAULT;
      ALTER TABLE assistencia ALTER COLUMN codigo DROP DEFAULT;
      ALTER TABLE banco ALTER COLUMN cod_banco DROP DEFAULT;
      ALTER TABLE bancocheques ALTER COLUMN cod_dadoscheque DROP DEFAULT;
      ALTER TABLE bancoconta ALTER COLUMN cod_bancoconta DROP DEFAULT;
      ALTER TABLE cidade ALTER COLUMN cod_cidade DROP DEFAULT;
      ALTER TABLE empresa ALTER COLUMN cod_empresa DROP DEFAULT;
      ALTER TABLE estado ALTER COLUMN cod_estado DROP DEFAULT;
      ALTER TABLE formaspagamento ALTER COLUMN cod_formaspagamento DROP DEFAULT;
      ALTER TABLE imagem ALTER COLUMN cod_image DROP DEFAULT;
      ALTER TABLE parametros ALTER COLUMN cod_parametro DROP DEFAULT;
      ALTER TABLE parametrosempresa ALTER COLUMN cod_parametroempresa DROP DEFAULT;
      ALTER TABLE permissao ALTER COLUMN cod_permissao DROP DEFAULT;
      ALTER TABLE tiposhistoricoscaixa ALTER COLUMN cod_tphitorico DROP DEFAULT;
      ALTER TABLE tiposlancamento ALTER COLUMN cod_tppagamento DROP DEFAULT;
    SQL
  end
end
