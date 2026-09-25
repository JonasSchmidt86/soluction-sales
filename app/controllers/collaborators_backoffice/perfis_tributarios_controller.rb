class CollaboratorsBackoffice::PerfisTributariosController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_perfil, only: [:show, :edit, :update, :destroy]

  def index
    @perfis = PerfilTributario.order(:nome)
  end

  def show
  end

  def new
    @perfil = PerfilTributario.new(ativo: true)
    # ja inicia com uma regra de Venda em branco para facilitar
    @perfil.regras.build(
      cod_operacao_fiscal: operacao_venda&.cod_operacao_fiscal,
      cod_empresa: current_empresa_id,
      uf_destino: "*", tipo_cliente: "*"
    )
  end

  def create
    @perfil = PerfilTributario.new(perfil_params)
    if @perfil.save
      redirect_to collaborators_backoffice_perfil_tributario_path(@perfil),
                  notice: "Perfil tributário criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @perfil.update(perfil_params)
      redirect_to collaborators_backoffice_perfil_tributario_path(@perfil),
                  notice: "Perfil tributário atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @perfil.produtos.exists?
      redirect_to collaborators_backoffice_perfis_tributarios_path,
                  alert: "Não é possível excluir: há produtos usando este perfil."
    else
      @perfil.destroy
      redirect_to collaborators_backoffice_perfis_tributarios_path,
                  notice: "Perfil tributário excluído."
    end
  end

  private

  def set_perfil
    @perfil = PerfilTributario.find(params[:id])
  end

  def perfil_params
    params.require(:perfil_tributario).permit(
      :nome, :descricao, :ativo,
      regras_attributes: [
        :id, :cod_operacao_fiscal, :cod_empresa,
        :uf_destino, :tipo_cliente, :cfop_base, :csosn,
        :aliquota_icms, :cst_pis, :cst_cofins, :cclasstrib, :cst_ibs_cbs,
        :soma_total_nota, :soma_duplicatas, :controla_estoque,
        :prioridade, :ativo, :_destroy
      ]
    )
  end

  def operacao_venda
    OperacaoFiscal.find_by(nome: "Venda")
  end

  def current_empresa_id
    current_collaborator.cod_empresa
  end

  # Módulo em desenvolvimento: acessível apenas por quem tem a permissão fiscal_perfis.
  def autorizar_fiscal!
    unless access_control.can_view?("fiscal_perfis")
      redirect_to collaborators_backoffice_welcome_index_path,
                  alert: "Acesso negado."
    end
  end
end
