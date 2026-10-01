class CollaboratorsBackoffice::VendasController < CollaboratorsBackofficeController

    before_action :set_venda, only: [:destroy]

    def index
      # @sale = Venda.where("cod_empresa = ? an tipo = 'V'", current_collaborator.cod_empresa).order(:cod_venda)
      # @sale = Venda.new(params_venda)
      # @codigo = Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
    end
  
    def consulta_estoque
      # puts "CONSULTA ESTOQUE #{params} "x
      @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade, :ultimocusto)
                   .joins(:empresaprodutos)
                   .where("cod_produto = ? and cod_empresa = ? and cores.ativo = true and empresaproduto.ativo = true", params[:id_produto], current_collaborator.cod_empresa)
                   .order(quantidade: :desc, nmcor: :asc, cod_cor: :asc)
      if @cores.empty?
        @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade, :ultimocusto)
                      .joins(:empresaprodutos).select(:cod_empresa)
                      .where("cod_produto = ?", params[:id_produto])
                      .order(valorvenda: :desc)
                      .limit(1);
        @cores.each do |core|
          if(core.cod_empresa != current_collaborator.cod_empresa)
            core.cod_cor = 1;
            core.nmcor = "PADRAO";
            core.quantidade = 0;
            core.ultimocusto = 0;
          end
        end
      end

      respond_to do |format|
        format.json { render json: @cores }
      end
    end

    def new
      if params[:orcamento_id]
        orcamento = Orcamento.find(params[:orcamento_id])
        @sale = Venda.new(
          tipo: 'V',
          cod_empresa: orcamento.cod_empresa,
          cod_pessoa: orcamento.cod_pessoa,
          cod_funcionario: orcamento.cod_funcionario,
          datavenda: Time.current,
          valortotal: orcamento.valortotal,
          desconto: 0,
          acrescimo: 0
        )

        orcamento.itens_orcamentos.each do |item|
          item_venda = @sale.itensvenda.build(
            cod_produto: item.cod_produto,
            cod_cor: item.cod_cor,
            cod_empresa: item.cod_empresa,
            quantidade: item.quantidade.to_i
          )
          # Formata valores no padrão brasileiro para a máscara JS processar corretamente
          item_venda.valorunitario = '%.2f' % item.valorunitario
          item_venda.valor_desconto = '%.2f' % (item.valor_desconto || 0)
          item_venda.valor_acrescimo = '%.2f' % (item.valor_acrescimo || 0)
        end

        session[:orcamento_id] = orcamento.cod_orcamento
      else
        @sale = Venda.new
        @sale.cod_empresa = current_collaborator.cod_empresa
        2.times { @sale.itensvenda.build }
      end
    end
  
    def create
      # Idempotencia: cada carregamento do form gera um submit_token unico.
      # Se o mesmo token chegar duas vezes (duplo clique / reenvio), ignora
      # o segundo POST para nao duplicar a venda.
      token = params.dig(:venda, :submit_token)
      session[:vendas_submit_tokens] ||= []
      if token.present? && session[:vendas_submit_tokens].include?(token)
        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda já registrada."
        return
      end

      # Nested attributes + MoedaBr cuidam de itens/contas/valores.
      # (reject_if no model descarta linhas em branco; os setters convertem BR.)
      @sale = Venda.new(params_venda)

      # Transferencia (tipo 'T'): contas sao geradas pelo TransferenciaService
      # no after_commit, entao limpamos as que vieram do form.
      @sale.contas.clear if @sale.transferencia?

      aplicar_pessoa!(@sale)
      aplicar_metadados_venda!(@sale, nova: true)

      if transferencia_sem_destino?(@sale)
        @sale.errors.add(:base, "Transferência sem Empresa de Destino!")
        render :new, status: :unprocessable_entity
        return
      end

      if @sale.save
        session[:vendas_submit_tokens] = (session[:vendas_submit_tokens] + [token]).last(20) if token.present?
        if session[:orcamento_id]
          orcamento = Orcamento.find_by(cod_orcamento: session[:orcamento_id])
          orcamento&.update(status: 'convertido', cod_venda: @sale.cod_venda)
          session.delete(:orcamento_id)
        end

        return if emitir_nfe_apos_salvar?(@sale)

        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda cadastrada com sucesso!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @sale = Venda.find(params[:id])
      unless @sale.editavel?
        redirect_to collaborators_backoffice_report_sales_path, alert: motivo_bloqueio_edicao(@sale)
      end
    end

    # Edicao plena da venda (itens/cores/quantidades/valores/contas) via nested
    # attributes. UPDATE em item/conta existente (tem :id) => trigger ajusta o
    # estoque pelo delta/troca; novo (sem :id) => INSERT; _destroy => DELETE.
    def update
      @sale = Venda.find(params[:id])

      unless @sale.editavel?
        redirect_to collaborators_backoffice_report_sales_path, alert: motivo_bloqueio_edicao(@sale)
        return
      end

      # Garante autoria correta nos logs de estoque do trigger (le VENDA.cod_funcionario).
      @sale.cod_funcionario = current_collaborator.cod_funcionario

      aplicar_pessoa!(@sale)

      if @sale.update(params_venda_update)
        return if emitir_nfe_apos_salvar?(@sale)

        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda atualizada com sucesso!"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy

      @sale.contas.each do |conta|
        if !conta.lancamentos.blank?
          @caixa = Caixa.where(" cod_empresa = ? and datafechamento is null ", current_collaborator.empresa.cod_empresa).first
          puts  "CAIXA ENCONTRADO: #{@caixa.present?} - COD CAIXA: #{@caixa&.id}"
          if @caixa.nil?
            redirect_to collaborators_backoffice_report_sales_path, notice: "Não foi possível cancelar a venda, caixa fechado!"
            return
          end
          puts "ESTORNANDO CONTA COD: #{conta.cod_contaspagrec} - COD VENDA: #{conta.venda.cod_venda}"
          # ver como vai cancelar a venda o que fazer com os lançamentos
          EstornarContaService.new(conta, current_collaborator, @caixa).call
        end
        conta.update!(ativo: false)
      end

      # Cancela a venda e os itens para devolver estoque
      if !@sale.cancelada
        @sale.update_columns(cancelada: true, cod_funcionario: current_collaborator.cod_funcionario)
        @sale.itensvenda.where(cancelado: [false, nil]).update_all(cancelado: true)
        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda cancelada com sucesso!"
        return
      end
      
      # Se já estava cancelada, pode excluir apenas se não teve movimentação no caixa
      teve_lancamentos = @sale.contas.joins(:lancamentos).exists?

      if teve_lancamentos
        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda cancelada mantida para auditoria (possui lançamentos no caixa)."
        return
      end

      # Se a venda veio de um orçamento, atualiza o orçamento
      orcamento = Orcamento.find_by(cod_venda: @sale.cod_venda)
      orcamento.update(status: 'pendente', cod_venda: nil) if orcamento

      # Marca quem está excluindo para o log do trigger
      @sale.update_column(:cod_funcionario, current_collaborator.cod_funcionario)

      if @sale.destroy
        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda Excluida com sucesso!"
      else
        redirect_to collaborators_backoffice_report_sales_path, notice: "Não foi possivel excluir venda!"
      end

      rescue => e
        redirect_to collaborators_backoffice_report_sales_path, notice: "Erro ao excluir a venda!"
    end

    def check_cpf_cnpj_venda
      cpf_cnpj = params[:cpf_cnpj].gsub(/\D/, '')  # Remove todos os caracteres não numéricos
      pessoa = Pessoa.find_by(cpf_cnpj: cpf_cnpj)
      
      # Verifica se uma pessoa foi encontrada
      if pessoa
        puts pessoa
        render json: pessoa
      else
        render json: { status: 'not_found' }
      end
    end

    def atualizar_vendedor
      @venda = Venda.find(params[:id])
      @venda.cod_funcionario = Funcionario.find_by(cod_funcionario: params[:cod_funcionario]).cod_funcionario if params[:cod_funcionario].present?  

      if @venda.save!
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda), notice: "Vendedor atualizado com sucesso."
      else
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda), alert: "Erro ao atualizar vendedor."
      end
    end

    private

    def vendedor_params
      params.require(:venda).permit(:cod_funcionario)
    end

    def set_venda
      @sale = Venda.includes(:contas).find(params[:id])
    end

    # Resolve a pessoa da venda: usa a existente (cod_pessoa) ou cria uma nova
    # com os pessoa_attributes do form. Mantem o comportamento do create antigo.
    def aplicar_pessoa!(sale)
      pa = params[:venda][:pessoa_attributes] || {}
      pessoa = Pessoa.find_by(cod_pessoa: params[:venda][:cod_pessoa]) if params[:venda][:cod_pessoa].present?

      if pessoa.nil?
        pessoa = Pessoa.new
        pessoa.cpf_cnpj = pa[:cpf_cnpj] if pa[:cpf_cnpj].present?
        pessoa.rg_ie   = pa[:rg_ie]    if pa[:rg_ie].present?
      end

      pessoa.telefone   = pa[:telefone]   if pa[:telefone].present?
      pessoa.celular    = pa[:celular]    if pa[:celular].present?
      pessoa.cep        = pa[:cep]        if pa[:cep].present?
      pessoa.cod_cidade = pa[:cod_cidade] if pa[:cod_cidade].present?
      pessoa.complemento = pa[:complemento] if pa[:complemento].present?
      pessoa.endereco   = pa[:endereco]   if pa[:endereco].present?
      pessoa.bairro     = pa[:bairro]     if pa[:bairro].present?
      pessoa.numero     = pa[:numero]     if pa[:numero].present?
      pessoa.email      = pa[:email]      if pa[:email].present?

      sale.pessoa = pessoa
    end

    # Metadados que o form nao envia (ou nao deve controlar): numero sequencial
    # da venda na empresa, empresa/funcionario logados, tipo default e destino
    # da transferencia. 'nova: true' gera o cod_vendaempresa.
    def aplicar_metadados_venda!(sale, nova:)
      if nova
        sale.cod_vendaempresa = (Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) || 0) + 1
        sale.cancelada = false
        sale.datanf = nil
      end
      sale.cod_empresa = current_collaborator.cod_empresa
      sale.cod_funcionario = current_collaborator.cod_funcionario
      sale.tipo = 'V' if sale.tipo.blank?

      if sale.transferencia? && sale.cod_empresa_transferida.blank?
        sale.cod_empresa_transferida = Empresa.find_by(cod_pessoa: sale.pessoa&.cod_pessoa)&.cod_empresa
      end
    end

    def transferencia_sem_destino?(sale)
      sale.transferencia? && Empresa.find_by(cod_empresa: sale.cod_empresa_transferida).nil?
    end

    def motivo_bloqueio_edicao(sale)
      if sale.nfe_autorizada?
        "Não é possível editar: a venda já tem NF-e autorizada. Cancele a NF-e antes."
      else
        "Não é possível editar uma venda cancelada."
      end
    end

    # Se o form pediu "salvar e emitir" (param emitir_nfe), emite/reemite a NF-e
    # 55 da venda recem-salva e redireciona com o resultado. Retorna true quando
    # tratou (ja fez redirect), para o caller nao redirecionar de novo.
    #
    # So emite para super_admin logado em empresa com modulo fiscal (mesmo gate
    # do botao). Caso contrario, ignora o param silenciosamente (retorna false).
    def emitir_nfe_apos_salvar?(sale)
      return false unless params[:emitir_nfe].present?
      return false unless empresa_tem_modulo_fiscal? && access_control.super_admin?

      documento = Fiscal::EmissorFiscal.new(
        sale, modelo: 55, cod_funcionario: current_collaborator.cod_funcionario
      ).emitir

      if documento.autorizada?
        redirect_to collaborators_backoffice_report_sales_path,
                    notice: "Venda salva e NF-e autorizada. Chave: #{documento.chave_acesso}"
      else
        redirect_to edit_collaborators_backoffice_venda_path(sale),
                    alert: "Venda salva, mas a NF-e #{documento.status}: #{documento.mensagem_sefaz}"
      end
      true
    rescue Fiscal::EmissorFiscal::JaAutorizada => e
      redirect_to collaborators_backoffice_report_sales_path, alert: e.message
      true
    rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos => e
      redirect_to edit_collaborators_backoffice_venda_path(sale),
                  alert: "Venda salva. NF-e NÃO emitida — #{e.message}"
      true
    rescue => e
      Rails.logger.error("[Vendas#emitir_nfe_apos_salvar] venda #{sale.cod_venda}: #{e.class} - #{e.message}")
      redirect_to edit_collaborators_backoffice_venda_path(sale),
                  alert: "Venda salva, mas falhou ao emitir NF-e: #{e.message}"
      true
    end

    def params_venda
      params.require(:venda).permit(
        :tipo, :cod_empresa, :cancelada, :datanf, :datavenda, :numeronf, :valortotal, :cod_frete, :cod_funcionario, 
        :cod_empresa_transferida, :cod_vendaempresa, :acrescimo, :desconto, :aceita, :cod_pessoa,
        itensvenda_attributes: [:id, :cod_produto, :quantidade, :valorunitario, :valor_acrescimo, :valor_desconto, :cod_cor, :cod_empresa, :_destroy],
        contas_attributes: [  :id, :cod_venda, :dtvencimento, :numeroparcela, :valorparcela, 
                              :_destroy, :cod_empresa, :ativo, :quitada, :cod_tppagamento ],
        pessoa_attributes: [  :tipo, :nome, :telefone, :celular, :cep, 
                              :cod_cidade, :complemento, :endereco, :bairro, :numero, :email ]
      )
    end

    # Strong params da EDICAO. Difere do create:
    #  - nao permite campos de identidade (cod_empresa/cod_funcionario/
    #    cod_vendaempresa/cancelada/tipo) — sao controlados pelo servidor;
    #  - remove de contas_attributes as parcelas que ja tem lancamentos no
    #    caixa (nao podem ser alteradas/removidas por aqui).
    def params_venda_update
      permitido = params.require(:venda).permit(
        :datavenda, :valortotal, :acrescimo, :desconto, :aceita, :cod_pessoa,
        itensvenda_attributes: [:id, :cod_produto, :quantidade, :valorunitario, :valor_acrescimo, :valor_desconto, :cod_cor, :cod_empresa, :_destroy],
        contas_attributes: [:id, :cod_venda, :dtvencimento, :numeroparcela, :valorparcela, :_destroy, :cod_empresa, :ativo, :quitada, :cod_tppagamento],
        pessoa_attributes: [:tipo, :nome, :telefone, :celular, :cep, :cod_cidade, :complemento, :endereco, :bairro, :numero, :email]
      )

      if permitido[:contas_attributes].present?
        ids_travados = @sale.contas.select { |c| c.lancamentos.present? }.map { |c| c.cod_contaspagrec.to_s }
        permitido[:contas_attributes] = permitido[:contas_attributes].reject do |c|
          ids_travados.include?(c[:id].to_s)
        end
      end

      permitido
    end
    
  end
  