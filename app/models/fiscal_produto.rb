# Dados fiscais do produto POR EMPRESA (ncm/cfop/cest/origem/gtin/csosn/perfil
# + qtd_fiscal consolidada). Substitui, por empresa, os campos fiscais que hoje
# vivem no cadastro GLOBAL do produto.
#
# Fonte unica de leitura: use FiscalProduto.para(cod_empresa, cod_produto).
#   - Se existir registro da empresa -> retorna ele.
#   - Senao (transicao) -> retorna um Fallback que LE do produto global,
#     expondo a MESMA interface (ncm/cest/origem/gtin/csosn/perfil_tributario/
#     cod_perfil_tributario). Assim os consumidores nao precisam saber a origem.
#
# IMPORTANTE (regras do dominio):
#   - Na EMISSAO (saida) o CFOP/CSOSN vem SEMPRE da regra do perfil tributario.
#     O csosn/cfop daqui sao dado de CADASTRO/ENTRADA (informativo).
#   - A qtdfiscal POR COR continua em empresaproduto (triggers intactas). Este
#     qtd_fiscal e o total consolidado por produto (controle interno).
class FiscalProduto < ApplicationRecord
  self.table_name = "fiscal_produto"
  self.primary_key = "cod_fiscal_produto"

  belongs_to :produto, class_name: "Produto",
             foreign_key: "cod_produto", primary_key: "cod_produto", optional: true

  belongs_to :perfil_tributario, class_name: "PerfilTributario",
             foreign_key: "cod_perfil_tributario", primary_key: "cod_perfil_tributario",
             optional: true

  belongs_to :empresa, class_name: "Empresa",
             foreign_key: "cod_empresa", primary_key: "cod_empresa", optional: true

  validates :cod_empresa, presence: true
  validates :cod_produto, presence: true
  validates :cod_empresa, uniqueness: { scope: :cod_produto }

  # Formato fiscal: NCM 8 digitos, CEST 7 digitos, origem 0..8. Permite em
  # branco (nil/""), mas se informado precisa estar no formato certo — evita
  # gravar dado fiscal invalido que a SEFAZ rejeitaria na emissao.
  validates :ncm,    format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_blank: true
  validates :cest,   format: { with: /\A\d{7}\z/, message: "deve ter 7 dígitos" }, allow_blank: true
  validates :origem, format: { with: /\A[0-8]\z/, message: "deve ser de 0 a 8" }, allow_blank: true

  scope :ativos, -> { where(ativo: true) }
  scope :da_empresa, ->(cod_empresa) { where(cod_empresa: cod_empresa) }

  # Fonte unica de leitura do fiscal do produto para uma empresa.
  # Retorna o registro da empresa ou, na ausencia, um Fallback lendo do produto
  # global (mesma interface). Nunca retorna nil: sempre da pra ler ncm/perfil/etc.
  #
  #   fp = FiscalProduto.para(cod_empresa, cod_produto)
  #   fp.ncm, fp.cest, fp.origem, fp.gtin, fp.csosn
  #   fp.cod_perfil_tributario, fp.perfil_tributario
  def self.para(cod_empresa, cod_produto)
    return Fallback.new(nil) if cod_produto.blank?

    registro = find_by(cod_empresa: cod_empresa, cod_produto: cod_produto)
    return registro if registro

    Fallback.new(Produto.find_by(cod_produto: cod_produto))
  end

  # Objeto de transicao: expoe a interface do FiscalProduto lendo do produto
  # global, enquanto a fiscal_produto da empresa ainda nao foi populada. Some
  # naturalmente quando o backfill (Etapa 3) e a escrita (Etapa 5) cobrirem tudo.
  class Fallback
    attr_reader :produto

    def initialize(produto)
      @produto = produto
    end

    def ncm;    produto&.ncm;    end
    def cfop;   produto&.cfop;   end
    def cest;   produto&.cest;   end
    def origem; produto&.origem; end
    def gtin;   produto&.gtin;   end
    def csosn;  produto&.try(:csosn); end

    def cod_perfil_tributario
      produto&.cod_perfil_tributario
    end

    def perfil_tributario
      produto&.perfil_tributario
    end

    # qtd_fiscal nao existe no produto global; no fallback e sempre 0.
    def qtd_fiscal
      BigDecimal("0")
    end

    # Marca que veio do fallback (produto global), nao de um registro real.
    def fallback?
      true
    end

    def persisted?
      false
    end
  end

  # Nos registros reais, fallback? e false (contraparte do Fallback#fallback?).
  def fallback?
    false
  end
end
