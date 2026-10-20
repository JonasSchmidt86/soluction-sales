class CollaboratorsBackoffice::ProdutoPerfilFiscalController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  # GET .../produto_perfil_fiscal  -> lista de perfis tributarios ativos (JSON).
  def index
    perfis = PerfilTributario.ativos.order(:nome).map do |p|
      { cod_perfil_tributario: p.cod_perfil_tributario, nome: p.nome }
    end
    render json: perfis
  end

  # GET .../produto_perfil_fiscal/:cod_produto -> status fiscal do produto (JSON).
  # Informa o perfil atual (POR EMPRESA, via fiscal_produto) e as pendencias.
  def show
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render json: { erro: "Produto não encontrado" }, status: :not_found if produto.nil?

    fiscal = FiscalProduto.para(current_collaborator.cod_empresa, produto.cod_produto)
    render json: {
      cod_produto: produto.cod_produto,
      nome: produto.nome,
      cod_perfil_tributario: fiscal.cod_perfil_tributario,
      perfil_nome: fiscal.perfil_tributario&.nome,
      pendencias: pendencias_fiscais(fiscal)
    }
  end

  # PATCH .../produto_perfil_fiscal/:cod_produto -> grava o perfil na
  # fiscal_produto da EMPRESA (cria o registro se ainda nao existir).
  def update
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render json: { erro: "Produto não encontrado" }, status: :not_found if produto.nil?

    cod_perfil = params[:cod_perfil_tributario].presence
    if cod_perfil && PerfilTributario.where(cod_perfil_tributario: cod_perfil).none?
      return render json: { erro: "Perfil inválido" }, status: :unprocessable_entity
    end

    registro = FiscalProduto.find_or_initialize_by(
      cod_empresa: current_collaborator.cod_empresa,
      cod_produto: produto.cod_produto
    )
    if registro.update(cod_perfil_tributario: cod_perfil)
      fiscal = FiscalProduto.para(current_collaborator.cod_empresa, produto.cod_produto)
      render json: {
        cod_produto: produto.cod_produto,
        cod_perfil_tributario: fiscal.cod_perfil_tributario,
        perfil_nome: fiscal.perfil_tributario&.nome,
        pendencias: pendencias_fiscais(fiscal)
      }
    else
      render json: { erro: registro.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  # Pendencias fiscais a partir do fiscal da EMPRESA (fiscal_produto/fallback),
  # espelhando a logica do Produto#pendencias_fiscais mas por empresa.
  def pendencias_fiscais(fiscal)
    motivos = []
    motivos << "NCM ausente/zerado" if fiscal.ncm.blank? || fiscal.ncm == "00000000"
    motivos << "Sem perfil tributário" if fiscal.cod_perfil_tributario.blank?
    motivos << "Sem origem" if fiscal.origem.blank?
    motivos
  end

  # Mesmo gate do modulo fiscal usado na emissao: por ora so super_admin em
  # empresa com modulo fiscal ativo.
  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      render json: { erro: "Acesso negado" }, status: :forbidden
    end
  end
end
