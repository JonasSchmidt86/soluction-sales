class CollaboratorsBackoffice::VendasController < CollaboratorsBackofficeController

    before_action :set_venda, only: [:destroy]
    # Trocar cor exige o mesmo nivel da edicao de venda (1 ou 2). Trava no
    # servidor para nao depender so do botao escondido na view.
    before_action :exigir_nivel_edicao!, only: [:itens_cores, :atualizar_cores]

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

      # Preserva o vendedor original da venda: editar (ex.: so a cor) NAO deve
      # reatribuir a venda para quem esta editando. A troca de vendedor so
      # acontece se o form enviar explicitamente um cod_funcionario (campo so
      # visivel para nivel 1/2) — tratado em aplicar_vendedor_edicao!.
      vendedor_original = @sale.cod_funcionario
      aplicar_vendedor_edicao!(@sale, vendedor_original)

      aplicar_pessoa!(@sale)

      # Total ja pago (lancamentos no caixa) ANTES da edicao. Base de verdade
      # financeira: a edicao do form nao altera o que ja entrou no caixa.
      total_pago = @sale.valorRecebido.to_d.round(2)

      # Atribui os dados do form e deixa o before_validation recalcular o
      # valortotal a partir dos itens. Nao salva ainda: valida as regras de
      # consistencia financeira primeiro.
      @sale.assign_attributes(params_venda_update)
      @sale.valid? # dispara recalculo do valortotal

      unless venda_consistente_para_salvar?(@sale, total_pago)
        render :edit, status: :unprocessable_entity
        return
      end

      if @sale.save
        return if emitir_nfe_apos_salvar?(@sale)

        redirect_to collaborators_backoffice_report_sales_path, notice: "Venda atualizada com sucesso!"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Regras de consistencia financeira ao editar uma venda (alem das validacoes
    # normais do model). Retorna false e adiciona erros em @sale quando:
    #  - Caso 1: o novo total ficou MENOR que o valor ja pago no caixa
    #    (ex.: removeu item de uma venda ja parcialmente paga);
    #  - Caso 2: a soma das parcelas (contaspagrec ativas) nao bate com o novo
    #    total (ex.: adicionou item e nao regerou/ajustou as parcelas).
    # Transferencia e ignorada (contas geradas por outro fluxo).
    def venda_consistente_para_salvar?(sale, total_pago)
      return true if sale.transferencia?

      total = (sale.valortotal || 0).to_d.round(2)
      ok = true

      # Caso 1: total nao pode ficar abaixo do que ja foi pago.
      if total < total_pago
        sale.errors.add(:base,
          "O novo total da venda (R$ #{'%.2f' % total}) ficou menor que o valor ja pago " \
          "(R$ #{'%.2f' % total_pago}). Estorne o pagamento no financeiro antes de reduzir a venda.")
        ok = false
      end

      # Caso 2: soma das parcelas ativas (liquidadas + em aberto) deve bater com
      # o total. As liquidadas nao sao editaveis pelo form (ja filtradas em
      # params_venda_update), por isso usamos as contas atuais da venda.
      parcelas = sale.contas.reject(&:marked_for_destruction?).select { |c| c.ativo != false }
      unless parcelas.empty?
        soma_parcelas = parcelas.sum { |c| (c.valorparcela || 0).to_d }.round(2)
        if (soma_parcelas - total).abs > 0.01
          sale.errors.add(:base,
            "O total das parcelas (R$ #{'%.2f' % soma_parcelas}) nao confere com o total da venda " \
            "(R$ #{'%.2f' % total}). Ajuste as parcelas em aberto antes de salvar.")
          ok = false
        end
      end

      ok
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

    # Itens da venda (JSON) para o modal "Trocar Cor": codigo do item, nome do
    # produto e a cor atual. O select de cores no modal usa as cores ativas.
    def itens_cores
      venda = Venda.find(params[:id])
      itens = venda.itensvenda.where(cancelado: [false, nil]).map do |iv|
        {
          cod_item: iv.cod_item,
          cod_produto: iv.cod_produto,
          nome_produto: iv.nome_produto,
          cod_cor: iv.cod_cor
        }
      end
      render json: { cod_venda: venda.cod_venda, cod_vendaempresa: venda.cod_vendaempresa, itens: itens }
    end

    # Troca APENAS a cor (cod_cor) dos itens da venda. Edicao segura: nao altera
    # valor, itens nem parcelas — por isso e permitida mesmo em venda ja quitada
    # (onde a edicao normal esta bloqueada). O UPDATE em itemvenda dispara o
    # trigger de estoque, que move a quantidade da cor antiga para a nova.
    def atualizar_cores
      @venda = Venda.find(params[:id])

      # Nao faz sentido trocar cor de venda cancelada (itens ja estornados).
      if @venda.cancelada?
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda),
                    alert: "Não é possível trocar a cor de uma venda cancelada."
        return
      end

      # Autoria correta no log de estoque do trigger (le VENDA.cod_funcionario).
      @venda.update_column(:cod_funcionario, current_collaborator.cod_funcionario)

      cores = params[:cores] || {}
      alterados = 0

      ActiveRecord::Base.transaction do
        cores.each do |cod_item, cod_cor|
          next if cod_cor.blank?

          item = @venda.itensvenda.find_by(cod_item: cod_item)
          next if item.nil? || item.cod_cor.to_s == cod_cor.to_s

          # So aceita cor existente e ativa (evita cod_cor invalido vindo do form).
          next unless Core.exists?(cod_cor: cod_cor, ativo: true)

          item.update_column(:cod_cor, cod_cor)
          alterados += 1
        end
      end

      if alterados.positive?
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda),
                    notice: "Cor atualizada com sucesso (#{alterados} #{'item'.pluralize(alterados)})."
      else
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda),
                    notice: "Nenhuma cor foi alterada."
      end
    rescue => e
      Rails.logger.error("[atualizar_cores] venda #{params[:id]}: #{e.class} - #{e.message}")
      redirect_to collaborators_backoffice_report_sales_path(codigo_venda: params[:id]),
                  alert: "Erro ao atualizar a cor dos itens."
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
      # Vendedor: o logado e o default. Nivel 1/2 pode escolher outro no form;
      # quem nao pode tem o valor forcado para o logado (ignora POST forjado).
      vendedor_informado = sale.cod_funcionario
      if pode_alterar_vendedor? && vendedor_informado.present? &&
         Funcionario.exists?(cod_funcionario: vendedor_informado)
        sale.cod_funcionario = vendedor_informado
      else
        sale.cod_funcionario = current_collaborator.cod_funcionario
      end
      sale.tipo = 'V' if sale.tipo.blank?

      if sale.transferencia? && sale.cod_empresa_transferida.blank?
        sale.cod_empresa_transferida = Empresa.find_by(cod_pessoa: sale.pessoa&.cod_pessoa)&.cod_empresa
      end
    end

    # Define o vendedor (cod_funcionario) na EDICAO.
    #  - Mantem o vendedor original por padrao (nao rouba a venda de quem vendeu);
    #  - So troca se o usuario puder reatribuir (nivel 1/2) E o form enviar um
    #    cod_funcionario valido e diferente.
    def aplicar_vendedor_edicao!(sale, vendedor_original)
      sale.cod_funcionario = vendedor_original

      return unless pode_alterar_vendedor?

      novo = params.dig(:venda, :cod_funcionario)
      return if novo.blank?

      funcionario = Funcionario.find_by(cod_funcionario: novo)
      sale.cod_funcionario = funcionario.cod_funcionario if funcionario
    end

    # So niveis 1 e 2 podem reatribuir a venda a outro vendedor (mesma regra do
    # modal "Alterar Vendedor" no relatorio).
    def pode_alterar_vendedor?
      nivel = current_collaborator.funcionario&.permissao&.nivel
      [1, 2].include?(nivel)
    end
    helper_method :pode_alterar_vendedor?

    # Bloqueia quem nao e nivel 1/2 de acessar as actions de troca de cor
    # (mesma regra do botao "Trocar Cor"/"Editar Venda" na listagem).
    def exigir_nivel_edicao!
      nivel = current_collaborator.funcionario&.permissao&.nivel
      return if [1, 2].include?(nivel)

      respond_to do |format|
        format.json { render json: { erro: "Sem permissão." }, status: :forbidden }
        format.html do
          redirect_to collaborators_backoffice_report_sales_path,
                      alert: "Você não tem permissão para trocar a cor da venda."
        end
      end
    end

    def transferencia_sem_destino?(sale)
      sale.transferencia? && Empresa.find_by(cod_empresa: sale.cod_empresa_transferida).nil?
    end

    def motivo_bloqueio_edicao(sale)
      if sale.nfe_autorizada?
        "Não é possível editar: a venda já tem NF-e autorizada. Cancele a NF-e antes."
      elsif sale.cancelada?
        "Não é possível editar uma venda cancelada."
      elsif sale.totalmente_paga?
        "Não é possível editar: a venda já está 100% paga. Estorne o pagamento no financeiro antes de alterar."
      else
        "Não é possível editar esta venda."
      end
    end

    # Se o form pediu "salvar e emitir" (param emitir_nfe), emite/reemite a NF-e
    # 55 da venda recem-salva e redireciona com o resultado. Retorna true quando
    # tratou (ja fez redirect), para o caller nao redirecionar de novo.
    #
    # So emite para super_admin logado em empresa com modulo fiscal (mesmo gate
    # do botao). Caso contrario, ignora o param silenciosamente (retorna false).
    def emitir_nfe_apos_salvar?(sale)
      # DESATIVADO (Projeto 2, Etapa 6): a emissao direta da venda foi removida.
      # A NF agora passa SEMPRE pelo editor de nota: no relatorio de vendas, o
      # botao "Gerar NF" cria um rascunho a partir da venda (itens + destinatario)
      # e abre a tela para conferir, ajustar e emitir. Mantido aqui (sem emitir)
      # para reativacao futura, se necessario.
      false
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
      # NAO permite :cod_funcionario aqui de proposito: o vendedor da edicao e
      # controlado pelo servidor em aplicar_vendedor_edicao! (com checagem de
      # permissao), evitando que o campo seja forjado via POST.
      permitido = params.require(:venda).permit(
        :datavenda, :valortotal, :acrescimo, :desconto, :aceita, :cod_pessoa,
        itensvenda_attributes: [:id, :cod_produto, :quantidade, :valorunitario, :valor_acrescimo, :valor_desconto, :cod_cor, :cod_empresa, :_destroy],
        contas_attributes: [:id, :cod_venda, :dtvencimento, :numeroparcela, :valorparcela, :_destroy, :cod_empresa, :ativo, :quitada, :cod_tppagamento],
        pessoa_attributes: [:id, :tipo, :cpf_cnpj, :rg_ie, :nome, :telefone, :celular, :cep, :cod_cidade, :complemento, :endereco, :bairro, :numero, :email]
      )

      # Nested attributes de pessoa: sem o :id, o Rails CONSTROI uma pessoa nova
      # a partir dos pessoa_attributes (perdendo cpf_cnpj/rg_ie que vinham so do
      # banco) e a validacao estoura "CPF em branco". Com o :id correto, atualiza
      # a pessoa existente. Alem disso, se o form mandar cpf_cnpj/rg_ie em branco,
      # NAO apaga o que ja existe no banco (editar venda nao deve zerar o CPF do
      # cliente). Vale tambem quando a tela nao preencheu o campo escondido.
      if permitido[:pessoa_attributes].present? && params[:venda][:cod_pessoa].present?
        pa = permitido[:pessoa_attributes]
        pessoa_atual = Pessoa.find_by(cod_pessoa: params[:venda][:cod_pessoa])
        if pessoa_atual
          pa[:id] = pessoa_atual.cod_pessoa
          pa[:cpf_cnpj] = pessoa_atual.cpf_cnpj if pa[:cpf_cnpj].blank? && pessoa_atual.cpf_cnpj.present?
          pa[:rg_ie]    = pessoa_atual.rg_ie    if pa[:rg_ie].blank?    && pessoa_atual.rg_ie.present?
        end
      end

      if permitido[:contas_attributes].present?
        ids_travados = @sale.contas.select { |c| c.lancamentos.present? }.map { |c| c.cod_contaspagrec.to_s }

        # contas_attributes pode chegar como Array ([{...}]) ou como Parameters
        # com chaves indexadas ({"0" => {...}}). Normaliza para a LISTA de hashes
        # (so os valores) antes de filtrar, senao o reject itera o Parameters
        # como pares [chave, valor] e c[:id] estoura "Symbol into Integer".
        contas = permitido[:contas_attributes]
        lista = contas.respond_to?(:values) ? contas.values : Array(contas)

        permitido[:contas_attributes] = lista.reject do |c|
          ids_travados.include?(c[:id].to_s)
        end
      end

      permitido
    end
    
  end
  