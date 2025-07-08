class CollaboratorsBackoffice::VendasController < CollaboratorsBackofficeController

    before_action :set_venda, only: [:destroy, :editar_itens, :atualizar_itens]

    def index
      # @sale = Venda.where("cod_empresa = ? an tipo = 'V'", current_collaborator.cod_empresa).order(:cod_venda)
      # @sale = Venda.new(params_venda)
      # @codigo = Venda.where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
    end
  
    def consulta_estoque
      # puts "CONSULTA ESTOQUE #{params} "x
      @cores = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade, :ultimocusto)
                   .joins(:empresaprodutos)
                   .where("cod_produto = ? and cod_empresa = ?", params[:id_produto], current_collaborator.cod_empresa)
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
      @sale = Venda.new
      @sale.cod_empresa = current_collaborator.cod_empresa
      # @sale.itensvenda.build
      2.times { @sale.itensvenda.build }
      # @sale.contas.build
    end
  
    def create
      puts " -------- create ---------- #{params}"
      @sale = Venda.new(params_venda)

      @sale.acrescimo = params[:venda][:acrescimo].gsub(',', '.').to_f;
      @sale.desconto = params[:venda][:desconto].gsub(',', '.').to_f;
      @sale.valortotal =  params[:venda][:valortotal].gsub(',', '.').to_f;
      @sale.tipo =params[:venda][:tipo] if params[:venda][:tipo].present?;

      # varrer itens para validar valores quebrados
       ## ver como vai pegar o params certo para cada item
       if params[:venda][:itensvenda_attributes].present?
        itens = params[:venda][:itensvenda_attributes]
        
        # Verifique se itens é uma instância de ActionController::Parameters
        if itens.is_a?(ActionController::Parameters)
          # Converta itens para uma matriz de hashes
          itens = itens.values
        end

        @sale.itensvenda.clear;
        
        itens.each do |pro_temp|

          item = Itemvenda.new

          item.venda = @sale;
          item.cod_produto = pro_temp[:cod_produto];
          item.valorunitario = pro_temp[:valorunitario].gsub(',', '.').to_f;
          item.valor_desconto = pro_temp[:valor_desconto].gsub(',', '.').to_f;
          item.valor_acrescimo = pro_temp[:valor_acrescimo].gsub(',', '.').to_f;
          item.cod_cor = pro_temp[:cod_cor];
          item.quantidade = pro_temp[:quantidade];
          item.cod_empresa = pro_temp[:cod_empresa];
          @sale.itensvenda << item;
        end
      end

      if params[:venda][:contas_attributes].present?
        contas = params[:venda][:contas_attributes]
        
        # Verifique se itens é uma instância de ActionController::Parameters
        if contas.is_a?(ActionController::Parameters)
          # Converta itens para uma matriz de hashes
          contas = contas.values
        end

        @sale.contas.clear;
        
        contas.each do |conta_venda|

          conta = Contaspagrec.new

          conta.venda = @sale;
          conta.numeroparcela = conta_venda[:numeroparcela];
          conta.dtvencimento = conta_venda[:dtvencimento];
          conta.valorparcela = conta_venda[:valorparcela].gsub(',', '.').to_f;
          conta.cod_empresa = conta_venda[:cod_empresa];
          conta.ativo = true;
          conta.quitada = false;
          conta.cod_tppagamento = 1;

          @sale.contas << conta;
        end
      end

      if !params[:venda][:cod_pessoa].blank?
        @pessoa = Pessoa.find_by(cod_pessoa: params[:venda][:cod_pessoa])
      end
      if @pessoa.nil?
        @pessoa = Pessoa.new
        @pessoa.cpf_cnpj = params[:venda][:pessoa_attributes][:cpf_cnpj] if params[:venda][:pessoa_attributes][:cpf_cnpj].present?
        @pessoa.rg_ie = params[:venda][:pessoa_attributes][:cpf_cnpj] if params[:venda][:pessoa_attributes][:rg_ie].present?
      end

      @pessoa.email = params[:venda][:pessoa_attributes][:nome] if params[:venda][:pessoa_attributes][:nome].present?
      @pessoa.telefone = params[:venda][:pessoa_attributes][:telefone] if params[:venda][:pessoa_attributes][:telefone].present?
      @pessoa.celular = params[:venda][:pessoa_attributes][:celular] if params[:venda][:pessoa_attributes][:celular].present?
      @pessoa.cep = params[:venda][:pessoa_attributes][:cep] if params[:venda][:pessoa_attributes][:cep].present?
      @pessoa.cod_cidade = params[:venda][:pessoa_attributes][:cod_cidade] if params[:venda][:pessoa_attributes][:cod_cidade].present?
      @pessoa.complemento = params[:venda][:pessoa_attributes][:complemento] if params[:venda][:pessoa_attributes][:complemento].present?
      @pessoa.endereco = params[:venda][:pessoa_attributes][:endereco] if params[:venda][:pessoa_attributes][:endereco].present?
      @pessoa.bairro = params[:venda][:pessoa_attributes][:bairro] if params[:venda][:pessoa_attributes][:bairro].present?
      @pessoa.numero = params[:venda][:pessoa_attributes][:numero] if params[:venda][:pessoa_attributes][:numero].present?
      @pessoa.email = params[:venda][:pessoa_attributes][:email] if params[:venda][:pessoa_attributes][:email].present?
      
      @sale.pessoa = @pessoa

      @sale.cod_vendaempresa = Venda.select(:cod_vendaempresa).where(cod_empresa: current_collaborator.cod_empresa).maximum(:cod_vendaempresa) + 1
      @sale.cod_empresa = current_collaborator.cod_empresa
      @sale.cod_funcionario = current_collaborator.cod_funcionario
      if @sale.tipo.nil? || @sale.tipo.blank?
        @sale.tipo = 'V'
      elsif @sale.tipo == 'T'
        @sale.cod_empresa_transferida = Empresa.find_by(cod_pessoa: @sale.pessoa&.cod_pessoa)&.cod_empresa 
        if @sale.cod_empresa_transferida.nil?
          @sale.errors.add(:base, "Transferência sem Empresa de Destino!")
          render :new
          return
        end
      end
      
      @sale.cancelada = false
      @sale.datanf = nil

      # Crie uma nova coleção contendo apenas os itens desejados
      itens_a_manter = @sale.itensvenda.reject { |item_venda| item_venda.cod_produto.nil? }
      conta_a_manter = @sale.contas.reject { |conta| (conta.numeroparcela.blank? || conta.valorparcela.blank? ||  conta.dtvencimento.blank?) }

      # Atribua a nova coleção à associação
      @sale.itensvenda = itens_a_manter
      @sale.contas = conta_a_manter

      puts "ANTES DE SALVAR"

      if @sale.save
          redirect_to collaborators_backoffice_report_sales_path, notice: "Venda Cadastrado com sucesso!"
      else 
        puts @sale
        render :index
      end
    end

    def edit
      @sale = Venda.find_by(cod_venda: params[:id])
    end

    def destroy

      @sale.contas.each do |conta|
        if !conta.lancamentos.blank?
          # ver como vai cancelar a venda o que fazer com os lançamentos
          redirect_to collaborators_backoffice_report_sales_path, notice: "Venda possui lançamentos de caixa!"
          return
        end
      end

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
      @venda.funcionario = Funcionario.find_by(cod_funcionario: params[:cod_funcionario])

      if @venda.save!
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda), notice: "Vendedor atualizado com sucesso."
      else
        redirect_to collaborators_backoffice_report_sales_path(codigo_venda: @venda.cod_venda), alert: "Erro ao atualizar vendedor."
      end
    end

    def editar_itens
      unless current_collaborator.funcionario.permissao.nivel == 1
        redirect_to collaborators_backoffice_report_sales_path, alert: "Acesso negado."
        return
      end
      
      if @sale.cancelada
        redirect_to collaborators_backoffice_report_sales_path, alert: "Não é possível editar itens de uma venda cancelada."
        return
      end
      
      # Verificar se há contas com lançamentos
      @tem_lancamentos = @sale.contas.any? { |conta| conta.lancamentos.present? }
      
      @cores_disponiveis = {}
      
      @sale.itensvenda.each do |item|
        @cores_disponiveis[item.cod_produto] = Core.select(:nmcor, :cod_cor, :valorvenda, :quantidade, :ultimocusto)
                                                   .joins(:empresaprodutos)
                                                   .where("cod_produto = ? and cod_empresa = ?", item.cod_produto, current_collaborator.cod_empresa)
                                                   .order(quantidade: :desc, nmcor: :asc, cod_cor: :asc)
      end
    end

    def atualizar_itens
      unless current_collaborator.funcionario.permissao.nivel == 1
        redirect_to collaborators_backoffice_report_sales_path, alert: "Acesso negado."
        return
      end
      
      if @sale.cancelada
        redirect_to collaborators_backoffice_report_sales_path, alert: "Não é possível editar itens de uma venda cancelada."
        return
      end
      # Atualizar itens
      if params[:venda][:itensvenda_attributes].present?
        params[:venda][:itensvenda_attributes].each do |index, item_params|
          item = @sale.itensvenda.find(item_params[:id]) if item_params[:id].present?
          puts "ATUALIZANDO ITEM: #{item_params[:id]} - #{item_params[:valor_acrescimo]} - #{item_params[:valor_desconto]}"
          if item
            item.update(
              cod_cor: item_params[:cod_cor],
              valorunitario: item_params[:valorunitario].gsub(',', '.').to_f,
              valor_acrescimo: item_params[:valor_acrescimo]&.gsub(',', '.')&.to_f || 0,
              valor_desconto: item_params[:valor_desconto]&.gsub(',', '.')&.to_f || 0
            )
          end
        end
      end
      #  VERIFICAR SE ESTA GRAVANDO

      # Atualizar contas (apenas as que não têm lançamentos)
      if params[:venda][:contas_attributes].present?
        puts "CONTAS PARAMS: #{params[:venda][:contas_attributes]}"
        
        params[:venda][:contas_attributes].each do |index, conta_params|
          
          conta = @sale.contas.find_by(cod_contaspagrec: conta_params[:id])
          lancamentos = Lancamentoscaixa.where(cod_contaspagrec: conta_params[:id]) if conta_params[:id].present? 

          if conta && lancamentos
            begin
              puts "ATUALIZANDO CONTA ID: #{conta.id}"
              conta.update!(
                dtvencimento: conta_params[:dtvencimento],
                valorparcela: conta_params[:valorparcela].gsub(',', '.').to_f
              )
              puts "CONTA ATUALIZADA: #{conta.valorparcela}"
            rescue => e
              puts "ERRO AO ATUALIZAR CONTA ID #{conta.id}: #{e.message}"
            end
          else
            puts "CONTA NÃO ATUALIZADA - Lançamentos presentes: #{lancamentos.size}"
          end
        end
      else
        puts "NENHUMA CONTA PARA ATUALIZAR"
      end

      
      # Recalcular valor total da venda
      novo_valor_total = @sale.itensvenda.sum { |item| item.valor_total } + @sale.acrescimo - @sale.desconto
      @sale.update(valortotal: novo_valor_total.round(2))
      
      redirect_to collaborators_backoffice_report_sales_path, notice: "Venda atualizada com sucesso!"
    end

    private 
    
    def vendedor_params
      params.require(:venda).permit(:cod_funcionario)
    end

    def set_venda
      @sale = Venda.includes(:contas).find(params[:id])
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
    
  end
  