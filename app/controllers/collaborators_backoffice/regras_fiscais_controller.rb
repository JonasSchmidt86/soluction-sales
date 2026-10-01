class CollaboratorsBackoffice::RegrasFiscaisController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_perfil
  before_action :set_regra, only: [:edit, :update, :destroy]

  def new
    @regra = @perfil.regras.build(
      cod_empresa: current_collaborator.cod_empresa,
      uf_destino: "*", tipo_cliente: "*", ativo: true,
      soma_total_nota: true, soma_duplicatas: true, controla_estoque: "proprio"
    )
  end

  def create
    @regra = @perfil.regras.build(regra_params)
    @regra.cod_empresa ||= current_collaborator.cod_empresa
    if @regra.save
      redirect_to collaborators_backoffice_perfil_tributario_path(@perfil),
                  notice: "Regra fiscal criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @regra.update(regra_params)
      redirect_to collaborators_backoffice_perfil_tributario_path(@perfil),
                  notice: "Regra fiscal atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @regra.destroy
    redirect_to collaborators_backoffice_perfil_tributario_path(@perfil),
                notice: "Regra fiscal excluída."
  end

  private

  def set_perfil
    @perfil = PerfilTributario.find(params[:perfil_tributario_id])
  end

  def set_regra
    @regra = @perfil.regras.find(params[:id])
  end

  def regra_params
    params.require(:regra_fiscal).permit(
      :cod_operacao_fiscal, :cod_empresa, :uf_destino, :tipo_cliente,
      :cfop_base, :prioridade, :ativo,
      :soma_total_nota, :soma_duplicatas, :controla_estoque,
      # ICMS
      :csosn, :aliquota_icms, :aliquota_fcp,
      # PIS / COFINS
      :cst_pis, :aliquota_pis, :cst_cofins, :aliquota_cofins,
      # IBS / CBS
      :cst_ibs_cbs, :cclasstrib
    )
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
