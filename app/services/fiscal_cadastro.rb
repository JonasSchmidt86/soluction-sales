# Resultado neutro da consulta ao Cadastro de Contribuintes da SEFAZ
# (ConsultarCadastroSefaz): situacao cadastral, IE, credenciamento, dados
# cadastrais, endereco e contato.
#
# habilitado? = contribuinte apto (situacao 1). Util para validar o
# destinatario antes de emitir e evitar rejeicao por cadastro irregular.
#
# Provedor-neutro: qualquer adapter deve devolver isto.
class FiscalCadastro
  attr_reader :situacao_cod, :situacao, :cpf_cnpj, :ie, :razao_social,
              :nome_fantasia, :regime, :cnae, :uf, :fonte, :mensagem,
              :data_inicio, :data_baixa, :data_alteracao,
              :endereco, :contato, :bruto

  def initialize(sucesso:, situacao_cod: nil, situacao: nil, habilitado: false,
                 cpf_cnpj: nil, ie: nil, razao_social: nil, nome_fantasia: nil,
                 regime: nil, cnae: nil, credenciado_nfe: false, credenciado_cte: false,
                 uf: nil, fonte: nil, mensagem: nil,
                 data_inicio: nil, data_baixa: nil, data_alteracao: nil,
                 endereco: nil, contato: nil, bruto: nil)
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
    @credenciado_cte = credenciado_cte ? true : false
    @uf              = uf
    @fonte           = fonte
    @mensagem        = mensagem.presence
    @data_inicio     = data_inicio
    @data_baixa      = data_baixa
    @data_alteracao  = data_alteracao
    @endereco        = endereco # Hash { logradouro, numero, complemento, bairro, municipio, cep, uf }
    @contato         = contato  # Hash { telefone, email, fax }
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

  def credenciado_cte?
    @credenciado_cte
  end

  # Endereco em uma linha, para exibicao rapida.
  def endereco_linha
    return nil if endereco.blank?
    e = endereco.transform_keys(&:to_s)
    partes = [
      [e["logradouro"], e["numero"]].compact.join(", "),
      e["complemento"], e["bairro"],
      [e["municipio"], e["uf"]].compact.join("/"),
      e["cep"]
    ]
    partes.map { |p| p.to_s.strip }.reject(&:empty?).join(" - ").presence
  end
end
