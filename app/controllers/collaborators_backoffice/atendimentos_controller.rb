class CollaboratorsBackoffice::AtendimentosController < CollaboratorsBackofficeController

  before_action :set_atendimento, only: [:edit, :update, :destroy]

  def create
    @atendimento = Atendimento.new(atendimento_params)
    @atendimento.cod_empresa = current_collaborator.cod_empresa
    @atendimento.data_atendimento = Time.current
    @atendimento.cod_funcionario = current_collaborator.cod_funcionario
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
    buscar_cliente_por_telefone(@atendimento) if atendimento_params[:cod_cliente].blank?
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
    return if atendimento.cod_cliente.present? || atendimento.telefone.blank?
    telefone_numeros = atendimento.telefone.gsub(/\D/, '')
    pessoa = Pessoa.where(
      "REGEXP_REPLACE(celular, '[^0-9]', '', 'g') = ? OR REGEXP_REPLACE(telefone, '[^0-9]', '', 'g') = ?",
      telefone_numeros, telefone_numeros
    ).first
    puts "pessoa = #{pessoa.inspect}"
    atendimento.cod_cliente = pessoa.cod_pessoa if pessoa
    atendimento.nome = pessoa.nome if pessoa
  end

  def atendimento_params
    params.require(:atendimento).permit(:nome, :telefone, :origem_id, :vendeu, :cod_cliente, :cod_funcionario, :observacao, :data_atendimento)
  end

end
