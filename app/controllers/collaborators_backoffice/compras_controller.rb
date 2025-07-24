class CollaboratorsBackoffice::ComprasController < CollaboratorsBackofficeController


    def index
      @buys = Compra.where(cod_empresa: current_collaborator.empresa.cod_empresa).order(cod_compra: :desc).page(params[:page])
    end

    def show
      @compra = Compra.includes(itenscompra: :produto, contas: {}).find_by(cod_compra: params[:id])
    end

    def cadastrar_produto
      puts "retornou aqui  #{params}----------- \n\n"

      @produto = Produto.new
      @produto.cod_produto = Produto.last.cod_produto + 1
      @produto.nome = params[:query][:nome].to_s.upcase
      @produto.ucom = params[:query][:ucom].to_s.upcase
      @produto.cfop = params[:query][:cfop].to_s.upcase
      @produto.ncm = params[:query][:ncm].to_s.upcase
      @produto.cest = params[:query][:cest].to_s.upcase

      begin
        @produto.marca = params[:query][:brands].to_i
        @produto.grupo = params[:query][:grupo].to_i
        @produto.cod_margem = params[:query][:cod_margem].to_i
      rescue ActiveRecord::RecordNotFound => e
        render json: { erro: "Registro não encontrado: #{e.message}" }, status: :not_found and return
      end

      if @produto.save
        render json: @produto
      else
        render json: { errors: @produto.errors.full_messages }, status: :unprocessable_entity
      end
    end


    def consulta_estoque
      puts "CONSULTA ESTOQUE #{params} "


      @cores = Core.select(:nmcor, :cod_cor, :ultimocusto)
                   .joins(:empresaprodutos)
                   .where("cod_produto = ? and cod_empresa = ?", params[:id_produto], current_collaborator.cod_empresa)
                   .order(nmcor: :asc, cod_cor: :asc)
      if @cores.empty?
        @cores = Core.select(:nmcor, :cod_cor, :ultimocusto)
                      .joins(:empresaprodutos).select(:cod_empresa)
                      .where("cod_produto = ?", params[:id_produto])
                      .order(valorvenda: :desc)
                      .limit(1);
        @cores.each do |core|
          if(core.cod_empresa != current_collaborator.cod_empresa)
            core.cod_cor = 1;
            core.nmcor = "PADRAO";
          end
        end
        puts "RETORNOU #{@cores.size} cores"
      end

      respond_to do |format|
        format.json { render json: @cores }
      end
    end

    def new
      @compra = Compra.new
      2.times { @compra.itenscompra.build }
    end

    def create
      compra = Compra.new
      
      #puts " -------- create COMPRA ---------- #{params}"
      puts " -------- create COMPRA ----------"

      if params[:compra].present?
        compra.numeronf = params[:compra][:numeronf];
        compra.serienf = params[:compra][:serienf];
        compra.desconto = params[:compra][:desconto]&.gsub(',', '.').to_f || 0.0;
        compra.valorfrete = params[:compra][:valorfrete]&.gsub(',', '.').to_f || 0.0;
        # compra.valortotal = params[:compra][:valortotal]&.gsub(',', '.').to_f || 0.0;
        compra.valortotal = params[:compra][:Valor_liquido]&.gsub(',', '.').to_f || 0.0;

        compra.arquivoxml = params[:compra][:arquivoxml];
        unless params[:compra][:arquivoxml].present? 
          compra.valortotal = params[:compra][:valortotal]&.gsub(',', '.').to_f || 0.0;
        end

        compra.cancelada = false
        # compra.datacancelamento = params[:compra][:datacancelamento];
        compra.datacompra = Date.parse(params[:compra][:datacompra]);

        compra.dataemissao = Date.parse(params[:compra][:dataemissao]);
        
        compra.outrasdespesas = (params[:compra][:outrasdespesas].to_f + params[:compra][:vST].to_f + params[:compra][:vSeguro].to_f);
        
        compra.cod_compraempresa = (Compra.select(:cod_compraempresa).where("cod_empresa = ? ", current_collaborator.cod_empresa ).maximum(:cod_compraempresa) + 1);
        compra.cod_funcionario = current_collaborator.cod_funcionario
        compra.cod_empresa = current_collaborator.cod_empresa
        if params[:compra][:cod_pessoa].present?
          compra.cod_pessoa = params[:compra][:cod_pessoa].to_i
        else
          compra.cod_pessoa = params[:compra][:pessoa_attributes][:id].to_i
        end

        compra.pessoa.pessoacontato = params[:compra][:pessoa_attributes][:pessoacontato].try(:upcase) || ""
        compra.pessoa.telefonecontato = params.dig(:compra, :pessoa_attributes, :telefonecontato).to_s
        compra.pessoa.email = params.dig(:compra, :pessoa_attributes, :email).to_s

        if params[:compra][:xml_file].present?
          compra.xml_file = XmlFile.find(params[:compra][:xml_file].to_i)
        end

        if params[:compra][:itenscompra_attributes].present?
          itens = params[:compra][:itenscompra_attributes]
          
          # Verifique se itens é uma instância de ActionController::Parameters
          if itens.is_a?(ActionController::Parameters)
            # Converta itens para uma matriz de hashes
            puts itens.class
            itens = itens.values
          end

          # Agora você pode iterar sobre os itens
          errors = []
          itens.each do |pro_temp|
            next if pro_temp["cod_produto"].blank?
            puts "PRO_TEMP: #{pro_temp.inspect}"

            if pro_temp["cod_produto"].blank?
              error_message = "Informe o produto! #{JSON.parse(pro_temp[:pro_xml_temp])["nome"].to_s.upcase}!"
              return render json: { error: error_message }, status: :not_found
            end

            if pro_temp[:pro_xml_temp].present?
              xml_pro = JSON.parse(pro_temp[:pro_xml_temp])
              proXml = nil;

              if xml_pro["codigo"].present? && !xml_pro["codigo"].blank?
                proXml = Produtoxml.find(xml_pro["codigo"])
              end

              if !pro_temp["cod_produto"].present? && pro_temp["cod_produto"].blank?
                error_message = "Informe o produto #{xml_pro["nome"].to_s.upcase}!"
                return render json: { error: error_message }, status: :not_found
              end
              if !pro_temp["cod_cor"].present? && pro_temp["cod_cor"].blank?
                error_message = "Informe a cor do produto #{xml_pro["nome"].to_s.upcase}!"
                return render json: { error: error_message }, status: :not_found
              end

              if proXml.blank?
                
                if pro_temp["cod_cor"].present? && pro_temp["cod_produto"].present? && xml_pro["codigo"].blank? && proXml.blank?
                  
                  proXml = Produtoxml.where(cod_cor: pro_temp["cod_cor"].to_i, 
                                            cod_produto: pro_temp["cod_produto"].to_i,
                                            codproemissor: xml_pro["codproemissor"]).where(" nome ilike ? ", xml_pro["nome"].to_s.upcase.rstrip).order(:codigo).first
                  
                  puts proXml.blank?
                  # puts proXml.nome
                  # puts proXml.infadicionais.present?
                  # puts xml_pro["infadicionais"]
                  # puts xml_pro["infadicionais"].to_s.rstrip.upcase

                  if !proXml.blank?
                    unless proXml.infadicionais.nil? && (xml_pro["infadicionais"].nil? || xml_pro["infadicionais"].to_s.strip.empty?) ||
                      proXml.infadicionais.to_s.rstrip.upcase == xml_pro["infadicionais"].to_s.rstrip.upcase
                      proXml = nil  
                    end
                  end
                  puts "Passou o unless"
                end
              end

              if proXml.blank?
                proXml = Produtoxml.new
                proXml.codproemissor = xml_pro["codproemissor"]
                proXml.infadicionais = xml_pro["infadicionais"].to_s.rstrip.upcase if xml_pro["infadicionais"].present?
                proXml.nome = xml_pro["nome"].to_s.rstrip.upcase if xml_pro["nome"].present?
                proXml.ucom = xml_pro["ucom"]
                proXml.ncm = xml_pro["ncm"]
                proXml.cfop = xml_pro["cfop"]
                proXml.cest = xml_pro["cest"]
              end

              proXml.cod_produto = pro_temp["cod_produto"]
              proXml.cod_cor = pro_temp["cod_cor"]
              proXml.cod_pessoa = compra.cod_pessoa

              unless proXml.save!
                error_message = "Erro ao cadastrar novo produtoXML #{xml_pro["nome"].to_s.rstrip.upcase  if xml_pro["nome"].present?}!"
                return render json: { error: error_message }, status: :not_found
              else
                xml_pro["codigo"] = proXml.codigo;
                puts "\n Produto Salvo! #{proXml.codigo } \n\n"
              end
            end
            
            itemCompra = Itemcompra.new

            itemCompra.cod_compra = compra.cod_compra
            itemCompra.cod_empresa = compra.cod_empresa
            itemCompra.cod_produto = pro_temp["cod_produto"]
            
            itemCompra.icms = pro_temp["icms"] 
            itemCompra.ipi = pro_temp["ipi"]&.gsub(',', '.').to_f
            itemCompra.valor_frete = pro_temp["valor_frete"]&.gsub(',', '.').to_f || 0.0
            itemCompra.valorunitario = pro_temp["valorunitario"]&.gsub(',', '.').to_f || 0.0

            itemCompra.numeronf = compra.numeronf
            itemCompra.quantidade = pro_temp["quantidade"]
            itemCompra.valorst = pro_temp["icms"]&.gsub(',', '.').to_f || 0.0
            itemCompra.cod_cor = pro_temp["cod_cor"]
            itemCompra.cancelado = false

            compra.itenscompra << itemCompra;

          end
        end
      end
      
      # frete
      if params[:compra][:frete].present?

        if !params[:compra][:frete][:cod_pessoa].blank?

          frete = Frete.new;
          frete.compra = compra;
          frete.cod_pessoa = params[:compra][:frete][:cod_pessoa].to_i;
          frete.cod_empresa = compra.cod_empresa
          frete.ativo = true;
          frete.datacadastro = Date.parse(params[:compra][:frete][:datacadastro]);
          frete.datavencimento =  Date.parse(params[:compra][:frete][:datavencimento]);
          frete.valor = params[:compra][:frete][:valor].gsub(',', '.').to_f;
          frete.nrromaneio = params[:compra][:frete][:nrromaneio];
          compra.frete = frete;

          conta = Contaspagrec.new
          
          conta.cod_empresa = frete.cod_empresa;
          conta.ativo = true
          conta.compra = compra
          conta.frete = frete
          conta.dtvencimento = frete.datavencimento
          conta.numeroparcela = 0
          conta.quitada = false
          conta.valorparcela = frete.valor

          frete.contas << conta;

          # tenho que salvar o frete primeiro para a trigger do postgres funcionar
          if frete.save!
            # Criar a compra
            compra.cod_frete = frete.cod_frete
            compra.valortotal += frete.valor
            puts "Frete persistido!"
          end
          
        end
      end

      # contas Pagar
      if params[:compra][:contas_attributes].present?
        contas = params[:compra][:contas_attributes]
          # Verifique se itens é uma instância de ActionController::Parameters
          if contas.is_a?(ActionController::Parameters)
            # Converta contas para uma matriz de hashes
            contas = contas.values
          end
          contas.each do |bill|
            next if bill["dtvencimento"].blank? || bill["numeroparcela"].blank? || bill["valorparcela"].blank?
            conta = Contaspagrec.new

            conta.cod_empresa = bill["cod_empresa"].to_i
            conta.ativo = true
            conta.compra = compra
            conta.dtvencimento = Date.parse(bill["dtvencimento"])
            conta.numeroparcela = bill["numeroparcela"].to_i
            conta.quitada = false
            conta.valorparcela = bill["valorparcela"].gsub(',', '.').to_f
            # conta.cod_tppagamento = 1 #bill["cod_tppagamento"]
            compra.contas << conta
          end

      end
      
      if compra.contas.size <= 0
        error_message = "Informe a forma de pagamento!"
        return render json: { error: error_message }, status: :not_found
      end

      if compra.save!
        respond_to do |format|
          format.html { redirect_to edit_collaborators_backoffice_empresa_estoque_path(compra), notice: 'Compra criada com sucesso.' }
          format.json { render json: { message: 'Compra criada com sucesso', compra_url: edit_collaborators_backoffice_empresa_estoque_path(compra) }, status: :created }
        end
      else
        # Se houver erros na compra
        puts "ERRO: #{compra.errors.full_messages.join(', ')}"
        error_message = "ERRO: #{compra.errors.full_messages.join(', ')}"
        render json: { error: error_message }, status: :unprocessable_entity
      end

    end

    def edit
      @compra = Compra.find_by(cod_compra: params[:id])
    end

    def destroy
      @compra = Compra.find(params[:id])
    puts "PARAMETROS ---------- #{params}"
      unless @compra.blank?

        xml = @compra.xml_file;

        unless xml.blank? 
          xml.compra = nil
          xml.save
        end
          
        ActiveRecord::Base.transaction do
          @compra.xml_file = nil;
          if @compra.destroy
            redirect_to collaborators_backoffice_report_buy_path(request.query_parameters), notice: "Compra Excluída!"
          else
            raise ActiveRecord::Rollback, "Não foi possível Excluir a Compra!"
            redirect_to collaborators_backoffice_report_buy_path(request.query_parameters), notice: "Não foi possível Excluir a Compra!"
          end
        end
      else
        redirect_to collaborators_backoffice_report_buy_path(request.query_parameters), notice: "Compra não encontrada!"
      end
    end    

    private 

    def set_compra
      @compra = Compra.find(params[:id])
    end

    def params_compra
        params.require(:compra).permit(
        :cod_empresa,
        :cancelada,
        :datacompra,
        :dataemissao,
        :numeronf,
        :serienf,
        :valorfrete,
        :valortotal,
        :cod_funcionario,
        :cod_compraempresa,
        :cod_compra,
        :cod_pessoa,
        :arquivoxml,
        :desconto,
        :outrasdespesas,
        pessoa_attributes:[:nome, :cpf_cnpj, :rg_ie, :endereco, :pessoacontato, :telefonecontato, :email, :cod_pessoa],
        frete: [
          :cod_empresa,
          :ativo,
          :datacadastro,
          :datavencimento,
          :valor,
          :cod_pessoa,
          :nrromaneio
        ],
        itenscompra_attributes:[
          :cod_compra,
          :cod_empresa,
          :cod_produto,
          :icms,
          :ipi,
          :numeronf,
          :quantidade,
          :valorst,
          :valorunitario,
          :cod_cor,
          :cancelado
        ],
        contas_attributes:[
          :cod_empresa,
          :ativo,
          :cod_compra,
          :dtvencimento,
          :numeroparcela,
          :quitada,
          :valorparcela,
          :cod_tppagamento
        ]);
        
      end

  end
  