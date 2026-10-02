# Resultado neutro da consulta ao Cadastro de Contribuintes da SEFAZ
# (ConsultarCadastroSefaz): situacao cadastral, IE, credenciamento NF-e.
#
# habilitado? = contribuinte apto (situacao 1). Util para validar o
# destinatario antes de emitir e evitar rejeicao por cadastro irregular.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalCadastro
  attr_reader :situacao_cod, :situacao, :cpf_cnpj, :ie, :razao_social,
              :nome_fantasia, :regime, :cnae, :uf, :fonte, :mensagem, :bruto

  def initialize(sucesso:, situacao_cod: nil, situacao: nil, habilitado: false,
                 cpf_cnpj: nil, ie: nil, razao_social: nil, nome_fantasia: nil,
                 regime: nil, cnae: nil, credenciado_nfe: false, uf: nil,
                 fonte: nil, mensagem: nil, bruto: nil)
    @sucesso         = sucesso ? true : false
    @situacao_cod    = situacao_cod
    @situacao        = situacao
    @habilitado      = habilitado ? true : false
    @cpf_cnpj        = cpf_cnpj
    @ie              = ie
    @razao_social    = razao_social
    @nome_fantasia   = nome_fantasia
    @regime          = regime
    @cnae            = cnae
    @credenciado_nfe = credenciado_nfe ? true : false
    @uf              = uf
    @fonte           = fonte
    @mensagem        = mensagem.presence
    @bruto           = bruto
  end

  def sucesso?
    @sucesso
  end

  def habilitado?
    @habilitado
  end

  def credenciado_nfe?
    @credenciado_nfe
  end
end
