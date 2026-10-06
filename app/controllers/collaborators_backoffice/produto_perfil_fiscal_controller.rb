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
  # Informa o perfil atual (se houver) e as pendencias (NCM/origem/perfil).
  def show
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render json: { erro: "Produto não encontrado" }, status: :not_found if produto.nil?

    render json: {
      cod_produto: produto.cod_produto,
      nome: produto.nome,
      cod_perfil_tributario: produto.cod_perfil_tributario,
      perfil_nome: produto.perfil_tributario&.nome,
      pendencias: produto.pendencias_fiscais
    }
  end

  # PATCH .../produto_perfil_fiscal/:cod_produto -> grava o perfil no produto.
  def update
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render json: { erro: "Produto não encontrado" }, status: :not_found if produto.nil?

    cod_perfil = params[:cod_perfil_tributario].presence
    if cod_perfil && PerfilTributario.where(cod_perfil_tributario: cod_perfil).none?
      return render json: { erro: "Perfil inválido" }, status: :unprocessable_entity
    end

    if produto.update(cod_perfil_tributario: cod_perfil)
      render json: {
        cod_produto: produto.cod_produto,
        cod_perfil_tributario: produto.cod_perfil_tributario,
        perfil_nome: produto.perfil_tributario&.nome,
        pendencias: produto.pendencias_fiscais
      }
    else
      render json: { erro: produto.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  # Mesmo gate do modulo fiscal usado na emissao: por ora so super_admin em
  # empresa com modulo fiscal ativo.
  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      render json: { erro: "Acesso negado" }, status: :forbidden
    end
  end
end
