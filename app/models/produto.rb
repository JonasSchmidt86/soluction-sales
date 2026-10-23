class Produto < ApplicationRecord
    self.table_name = "produto"
    self.primary_key = "cod_produto"
  
    # Corrigindo alias de atributos
    alias_attribute :cod_grupo, :grupo
    alias_attribute :cod_marca, :marca
  
    # Associações corretas
    belongs_to :cod_grupo, foreign_key: 'grupo', primary_key: 'cod_grupo', class_name: 'Grupo' #, optional: true
    belongs_to :cod_marca, foreign_key: 'marca', primary_key: 'cod_marca', class_name: 'Marca' #, optional: true
    belongs_to :parametro, foreign_key: 'cod_margem', class_name: 'Parametro', optional: true
  
    has_many :produto_imagens, class_name: 'ProdutoImagem', foreign_key: 'cod_produto', dependent: :destroy, autosave: true, inverse_of: :produto
    # accepts_nested_attributes_for :produto_imagens, allow_destroy: true, reject_if: :all_blank
  
    # Perfil tributario (modulo fiscal). csosn/cfop no produto viram legado/fallback.
    belongs_to :perfil_tributario, class_name: 'PerfilTributario',
               foreign_key: 'cod_perfil_tributario', primary_key: 'cod_perfil_tributario',
               optional: true

    has_many :empresaprodutos, class_name: 'Empresaproduto', foreign_key: 'cod_produto', inverse_of: :produto
    has_many :itensvenda, class_name: 'Itemvenda', foreign_key: 'cod_produto', inverse_of: :produto
    has_many :itenscompra, class_name: 'Itemcompra', foreign_key: 'cod_produto', inverse_of: :produto
  
    # Validações
    validates :cod_produto, presence: true, uniqueness: true
    validates :nome, presence: true
    validates :ucom, presence: false

    # Formato fiscal (NCM 8 digitos, CEST 7, origem 0..8). Valida SO quando o
    # campo e ALTERADO, para nao travar a edicao de produtos legados que ja
    # estao no banco com valor invalido (so exige corrigir quando mexer no campo).
    validates :ncm,    format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" },
              allow_blank: true, if: -> { will_save_change_to_ncm? }
    validates :cest,   format: { with: /\A\d{7}\z/, message: "deve ter 7 dígitos" },
              allow_blank: true, if: -> { will_save_change_to_cest? }
    validates :origem, format: { with: /\A[0-8]\z/, message: "deve ser de 0 a 8" },
              allow_blank: true, if: -> { will_save_change_to_origem? }
  
    def valor_site_por_cor(cod_cor)
      registros = empresaprodutos.select { |ep| ep.cod_cor.to_i == cod_cor.to_i && ep.valor_site.to_f > 0 }
      registros.map(&:valor_site).max
    end

    # Scopes
    scope :ativos, -> { where(ativo: true) }
    scope :inativos, -> { where(ativo: false) }
    scope :com_imagem_e_publicado, -> {
      joins(:produto_imagens, :empresaprodutos)
        .where('empresaprodutos.cod_produto = produto_imagens.cod_produto AND empresaprodutos.cod_cor = produto_imagens.cod_cor')
        .where(empresaprodutos: { publicado: true })
        .order(nome: :asc, cod_produto: :asc)
        .distinct
  }

    # Métodos de busca
    def self.search(query)
      where("cod_produto LIKE ? OR nome LIKE ?", "%#{query}%", "%#{query}%")
    end
  
    def cod_nome
      "#{nome} - #{cod_produto}"
    end

    # Percentual de margem aplicavel ao produto: primeiro a margem do proprio
    # produto (parametros.margemproduto via cod_margem), depois a margem do grupo
    # como fallback. Considera apenas parametros ativos (igual a trigger de compra).
    def margem_aplicada
      pct = (parametro&.ativo ? parametro.margemproduto.to_f : 0.0)
      return pct if pct > 0

      grupo_margem = cod_grupo&.cod_margem
      return 0.0 if grupo_margem.blank?
      Parametro.where(ativo: true, cod_parametro: grupo_margem).pick(:margemproduto).to_f
    end

    # Valor de venda calculado a partir de um custo aplicando a margem do produto
    # (ou do grupo). Mesma formula da trigger tgrf_estoquecompra:
    #   venda = custo * (1 + margem/100); sem margem, cai no proprio custo.
    # Usado no relatorio para exibir uma venda estimada quando a cadastrada e 0.
    def valor_venda_por_margem(custo)
      c = custo.to_f
      return 0.0 if c <= 0
      m = margem_aplicada
      m > 0 ? (c * (1 + m / 100)).round(2) : c
    end

    # Motivos que impedem a emissão fiscal deste produto (vazio = ok).
    def pendencias_fiscais
      motivos = []
      motivos << "NCM ausente/zerado" if ncm.blank? || ncm == "00000000"
      motivos << "Sem perfil tributário" if cod_perfil_tributario.blank?
      motivos << "Sem origem" if origem.blank?
      motivos
    end

    def apto_fiscal?
      pendencias_fiscais.empty?
    end
  
    def to_s
      nome
    end
  
    paginates_per 30
  end