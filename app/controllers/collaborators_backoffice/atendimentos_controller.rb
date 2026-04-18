class CollaboratorsBackoffice::AtendimentosController < CollaboratorsBackofficeController

  before_action :set_atendimento, only: [:edit, :update, :destroy]

  def create
    @atendimento = Atendimento.new(atendimento_params)
    @atendimento.company_id  = current_collaborator.cod_empresa
    @atendimento.attended_at = Time.current
    @atendimento.employee_id = current_collaborator.cod_funcionario
    if @atendimento.return_at.is_a?(String) && @atendimento.return_at.match?(/\A\d{2}\/\d{2}\/\d{4}\z/)
      @atendimento.return_at = Date.strptime(@atendimento.return_at, '%d/%m/%Y')
    end
    buscar_cliente_por_telefone(@atendimento)

    respond_to do |format|
      if @atendimento.save
        format.html { redirect_back fallback_location: collaborators_backoffice_root_path, notice: 'Atendimento registrado!' }
        format.json { render json: { message: 'Atendimento registrado com sucesso!' }, status: :created }
      else
        format.html { redirect_back fallback_location: collaborators_backoffice_root_path, alert: 'Erro ao registrar atendimento.' }
        format.json { render json: { errors: @atendimento.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    buscar_cliente_por_telefone(@atendimento) if atendimento_params[:customer_id].blank?
    if @atendimento.update(atendimento_params)
      redirect_to collaborators_backoffice_report_atendimentos_path, notice: 'Atendimento atualizado!'
    else
      render :edit
    end
  end

  def destroy
    @atendimento.destroy
    redirect_to collaborators_backoffice_report_atendimentos_path, notice: 'Atendimento excluído!'
  end

  private

  def set_atendimento
    @atendimento = Atendimento.find(params[:id])
  end

  def buscar_cliente_por_telefone(atendimento)
    return if atendimento.customer_id.present? || atendimento.phone.blank?
    telefone_numeros = atendimento.phone.gsub(/\D/, '')
    pessoa = Pessoa.where(
      "REGEXP_REPLACE(celular, '[^0-9]', '', 'g') = ? OR REGEXP_REPLACE(telefone, '[^0-9]', '', 'g') = ?",
      telefone_numeros, telefone_numeros
    ).first
    atendimento.customer_id = pessoa.cod_pessoa if pessoa
    atendimento.name        = pessoa.nome if pessoa
  end

  def atendimento_params
    params.require(:atendimento).permit(:name, :phone, :origem_id, :sold, :customer_id, :employee_id, :notes, :attended_at, :return_at, :status)
  end

end
