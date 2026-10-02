class CollaboratorsBackoffice::NotasAvulsasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_documento, only: [:show, :danfe, :cancelar]

  MODELOS = [55, 65].freeze

  # Lista as notas avulsas (documentos sem venda) da empresa logada.
  def index
    @documentos = DocumentoFiscal
                  .where(cod_empresa: current_collaborator.cod_empresa, cod_venda: nil)
                  .order(cod_documento_fiscal: :desc)
                  .limit(100)
  end

  # Formulario de emissao avulsa. modelo = 55 (NF-e, default) ou 65 (NFC-e).
  def new
    @modelo = modelo_param
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(nome: "NF avulsa") || OperacaoFiscal.find_by(nome: "Venda")
    @finalidades = DocumentoFiscal::FINALIDADES
  end

  # Emite a NF avulsa a partir dos itens (e destinatario, se 55).
  def create
    @modelo = modelo_param
    empresa = current_collaborator.empresa

    cliente = resolver_cliente
    if @modelo == 55 && cliente.nil?
      redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: 55),
                  alert: "NF-e (55) exige um destinatário. Informe o cliente."
      return
    end

    itens = itens_param
    if itens.empty?
      redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo),
                  alert: "Informe ao menos um produto."
      return
    end

    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "NF avulsa") ||
               OperacaoFiscal.find_by(nome: "Venda")

    avulso = Fiscal::DocumentoAvulso.new(empresa: empresa, cliente: cliente, itens: itens)
    documento = Fiscal::EmissorFiscal.new(avulso, modelo: @modelo,
                                          operacao: operacao,
                                          finalidade: params[:finalidade],
                                          cod_funcionario: current_collaborator.cod_funcionario).emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_notas_avulsa_path(documento),
                  notice: "NF autorizada. Chave: #{documento.chave_acesso}"
    else
      redirect_to collaborators_backoffice_notas_avulsas_path,
                  alert: "NF #{documento.status}: #{documento.mensagem_sefaz}"
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo), alert: e.message
  rescue => e
    Rails.logger.error("[NotasAvulsas#create] #{e.class} - #{e.message}")
    redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo),
                alert: "Falha ao emitir: #{e.message}"
  end

  def show
  end

  # POST /collaborators_backoffice/notas_avulsas/previsualizar
  # Gera o DANFE/DANFCE de PRE-VISUALIZACAO (sem transmitir a SEFAZ) a partir
  # dos itens/destinatario do formulario, usando a operacao/finalidade escolhidas.
  def previsualizar
    @modelo = modelo_param
    empresa = current_collaborator.empresa
    cliente = resolver_cliente
    itens   = itens_param

    if itens.empty?
      redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo),
                  alert: "Informe ao menos um produto para pré-visualizar."
      return
    end

    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
               OperacaoFiscal.find_by(nome: "NF avulsa") ||
               OperacaoFiscal.find_by(nome: "Venda")

    avulso  = Fiscal::DocumentoAvulso.new(empresa: empresa, cliente: cliente, itens: itens)
    preview = Fiscal::EmissorFiscal.new(avulso, modelo: @modelo, operacao: operacao,
                                        finalidade: params[:finalidade],
                                        cod_funcionario: current_collaborator.cod_funcionario)
                                   .pre_visualizar(tipo_arquivo: 1)

    if preview.sucesso?
      send_data preview.conteudo, filename: "previsualizacao-avulsa-#{@modelo}.pdf",
                type: "application/pdf", disposition: "inline"
    else
      redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo),
                  alert: "Não foi possível pré-visualizar: #{preview.erro}"
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo), alert: e.message
  rescue => e
    Rails.logger.error("[NotasAvulsas#previsualizar] #{e.class} - #{e.message}")
    redirect_to new_collaborators_backoffice_notas_avulsa_path(modelo: @modelo),
                alert: "Falha ao pré-visualizar: #{e.message}"
  end

  # PDF do DANFE (quando autorizada).
  def danfe
    if @documento.danfe_base64.blank?
      redirect_to collaborators_backoffice_notas_avulsa_path(@documento), alert: "DANFE indisponível."
      return
    end
    send_data Base64.decode64(@documento.danfe_base64),
              filename: "danfe-avulsa-#{@documento.cod_documento_fiscal}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  # Cancela a NF avulsa autorizada.
  def cancelar
    @documento.cancelar!(justificativa: params[:justificativa].to_s,
                         cod_funcionario: current_collaborator.cod_funcionario)
    redirect_to collaborators_backoffice_notas_avulsas_path, notice: "NF cancelada."
  rescue ArgumentError => e
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: e.message
  rescue NotImplementedError
    redirect_to collaborators_backoffice_notas_avulsas_path,
                alert: "Cancelamento ainda não implementado para este provedor."
  rescue => e
    Rails.logger.error("[NotasAvulsas#cancelar] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: "Falha ao cancelar: #{e.message}"
  end

  # Cores de um produto (JSON) para o select de cor no form.
  def cores_produto
    cores = Core.select(:nmcor, :cod_cor, :valorvenda)
                .joins(:empresaprodutos)
                .where("cod_produto = ? and cod_empresa = ?", params[:cod_produto], current_collaborator.cod_empresa)
                .order(:nmcor, :cod_cor)
    render json: cores.map { |c| { cod_cor: c.cod_cor, nmcor: c.nmcor, valorvenda: c.valorvenda } }
  end

  private

  def set_documento
    @documento = DocumentoFiscal.where(cod_empresa: current_collaborator.cod_empresa, cod_venda: nil)
                                .find(params[:id])
  end

  def modelo_param
    m = params[:modelo].to_i
    MODELOS.include?(m) ? m : 55
  end

  # Resolve o destinatario: usa cod_pessoa existente (busca) se informado.
  def resolver_cliente
    cod = params[:cod_pessoa].presence
    cod ? Pessoa.find_by(cod_pessoa: cod) : nil
  end

  # Monta a lista de itens a partir dos params do form.
  # Espera params[:itens] = [{ cod_produto, cod_cor, quantidade, valorunitario }, ...]
  def itens_param
    brutos = params[:itens]
    brutos = brutos.values if brutos.is_a?(ActionController::Parameters)
    Array(brutos).map { |i| i.permit(:cod_produto, :cod_cor, :quantidade, :valorunitario).to_h }
                 .reject { |i| i["cod_produto"].blank? }
                 .map do |i|
                   {
                     cod_produto:   i["cod_produto"],
                     cod_cor:       i["cod_cor"],
                     quantidade:    MoedaBr.parse(i["quantidade"]),
                     valorunitario: MoedaBr.parse(i["valorunitario"])
                   }
                 end
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
