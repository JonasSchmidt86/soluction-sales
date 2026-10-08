class CollaboratorsBackoffice::EmpresaEstoqueController < CollaboratorsBackofficeController
    
    # No edit, params[:id] e o CODIGO do produto/compra (nao o id do
    # empresaproduto), entao set_produto nao se aplica ali — rodava
    # Empresaproduto.find(codigo) e estourava RecordNotFound para codigo
    # inexistente. set_produto fica so em destroy/update (que usam o id real).
    before_action :set_produto, only: [:destroy, :update]

    def index
        # Inicializando a consulta base
        query = Empresaproduto.includes(:produto, :cor).select("empresaproduto.*")
                                .joins(:produto)
                                .order("produto.nome ASC, empresaproduto.cod_empresa ASC")
                                .where(empresaproduto: { ativo: true })
                                # .where(produtos: { cod_marca: params[:cod_marca] }) if params[:cod_marca].present?
                                # .where(produtos: { cod_grupo: params[:cod_grupo] }) if params[:cod_grupo].present?
        
        if params[:cod_marca].present?
            query = query.where(produto: { cod_marca: params[:cod_marca] })
        end
        if params[:cod_grupo].present?
            query = query.where(produto: { cod_grupo: params[:cod_grupo] })
        end
        
        # Adicionando condição para `term`
        if params[:term].present?
            term = params[:term].strip
            query = query.where(
            "produto.cod_produto::varchar = REPLACE(TRIM(?), '%', '') OR produto.nome ILIKE ?",
            term, "#{term}%"
            )
        end
        if !params[:contem].present?
            query = query.where("empresaproduto.quantidade > 0") 
        else
            # Adicionando condição para `contem`
            if params[:contem].present? && params[:contem] == '1'
                query = query.where.not(empresaproduto: { quantidade: 0 })
            elsif !params.key?(:contem) || !params.key?(:cod_empresa) || !params.key?(:term) || !params.key?(:cod_produto)
                query = query.where("empresaproduto.quantidade <= 0")
            else
                query = query.where("empresaproduto.quantidade > 0")
            end
        end
        
        # Adicionando condição para `cod_empresa`
        if params[:cod_empresa].present?
            query = query.where(empresaproduto: { cod_empresa: params[:cod_empresa] })
        end
        
        # Configurando paginação
        if params[:per_page] == 'Todas'
            @empresa_produtos = query
        else
            per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : 30
            if per_page == 0
            @empresa_produtos = query
            else
            @empresa_produtos = query.page(params[:page]).per(per_page)
            end
        end
    end

    def by_color
        @cor = Core.find(params[:cor_id])

        query = Empresaproduto.includes(:produto, :cor)
                                .joins(:produto)
                                .order("produto.nome ASC, empresaproduto.cod_empresa ASC")
                                .where(empresaproduto: { ativo: true, cod_cor: @cor.id })

        if params[:cod_empresa].present?
            query = query.where(empresaproduto: { cod_empresa: params[:cod_empresa] })
        end

        if params[:per_page] == 'Todas'
            @empresa_produtos = query
        else
            per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : 30
            @empresa_produtos = query.page(params[:page]).per(per_page)
        end
        # forma para passar parametros para o index ou qualquer outra view
        params[:term] = @empresa_produtos.first&.produto&.nome if @empresa_produtos.any?
        render :index
    end


    def update
        @empresa_produto.update_columns(
          valorvenda: params[:estoque][:valorvenda].gsub(',', '.').to_f,
          quantidademinima: params[:estoque][:quantidademinima].gsub(',', '.').to_f
        )
        render json: { message: "Valor atualizado com sucesso!", estoque: @empresa_produto }, status: :ok
      rescue => e
        render json: { message: "Erro ao atualizar valor.", errors: [e.message] }, status: :unprocessable_entity
    end

    # Atualiza várias linhas de uma vez (botão "Salvar todos").
    # Espera params[:itens] = [{ id:, valorvenda:, quantidademinima: }, ...]
    def update_todos
        itens = params[:itens] || []
        atualizados = 0

        ActiveRecord::Base.transaction do
            itens.each do |item|
                registro = Empresaproduto.find_by(id: item[:id])
                next unless registro

                valor = item[:valorvenda].to_s.gsub('.', '').gsub(',', '.').to_f
                qtd_min = item[:quantidademinima].to_s.gsub(',', '.').to_f

                registro.update_columns(valorvenda: valor, quantidademinima: qtd_min)
                atualizados += 1
            end
        end

        render json: { message: "#{atualizados} item(ns) atualizado(s) com sucesso!", total: atualizados }, status: :ok
    rescue => e
        render json: { message: "Erro ao salvar em lote.", errors: [e.message] }, status: :unprocessable_entity
    end

    def edit 
        # @empresa_produto
        puts "------------------ #{params} ------------------"
        
        if params[:format].present? && params[:format] === "produto"
            termo = params[:id].to_s.strip

            @empresa_produtos = Empresaproduto
                        .joins(:produto)
                        .where("empresaproduto.ativo = ?", true)

            # Busca por CODIGO quando o termo e so digitos; senao, por NOME (ILIKE).
            # Regras do padrao (respeita o que o usuario digitar):
            #  - Os % digitados sao preservados onde estiverem (inicio, meio, fim).
            #    So ha % no inicio ("contem") SE o usuario digitar, ex. "%rou".
            #  - Adicionamos % no final apenas se o usuario nao colocou um.
            # Ex.: "rou" -> "rou%" (comeca com); "%rou" -> "%rou%" (contem);
            #      "ROU%HEN%CA" -> "ROU%HEN%CA%".
            if termo.match?(/\A\d+\z/)
                @empresa_produtos = @empresa_produtos
                    .where("empresaproduto.cod_produto = ?", termo)
            else
                padrao = termo.end_with?("%") ? termo : "#{termo}%"
                @empresa_produtos = @empresa_produtos
                    .where("produto.nome ILIKE ?", padrao)
            end

            if params[:cod_cor].present?
                @empresa_produtos = @empresa_produtos
                    .where("empresaproduto.cod_cor = ?", params[:cod_cor])
            end

            @empresa_produtos = @empresa_produtos
                .order(cod_produto: :desc, cod_cor: :asc, cod_empresa: :asc)
        else

            query = Empresaproduto
                .joins("INNER JOIN itemcompra 
                            ON empresaproduto.cod_produto = itemcompra.cod_produto
                        AND empresaproduto.cod_cor = itemcompra.cod_cor")

                # 🔥 lógica fora da chain
                if params[:format] == "compra"
                query = query.joins("INNER JOIN compra 
                                        ON compra.cod_compra = itemcompra.cod_compra")
                            .where(compra: {
                                cod_compraempresa: params[:id],
                                cod_empresa: current_collaborator.empresa.cod_empresa
                            })
                else
                query = query.where(itemcompra: { cod_compra: params[:id] })
                end

                @empresa_produtos = query
                .where("empresaproduto.ativo = ? OR empresaproduto.quantidade > ?", true, 0)
                .where.not(empresaproduto: { quantidade: 0 })
                .order(cod_produto: :desc, cod_cor: :asc, cod_empresa: :asc)
        end

        # Nada encontrado para o codigo informado (produto/cor/compra inexistente
        # ou sem estoque): permanece NA MESMA tela de edicao, com uma mensagem e
        # os campos de filtro repreenchidos com o que foi buscado. @empresa_produtos
        # vem vazio (a view trata o estado sem iterar produtos nil).
        if @empresa_produtos.blank?
            @empresa_produtos = []
            @nao_encontrado   = mensagem_nada_encontrado
        end
    end

    def destroy
        if !@empresa_produto.blank?
            @empresa_produto.ativo = false
            if @empresa_produto.save
                redirect_to collaborators_backoffice_empresa_estoque_index_path, notice: "Produto Inativado!"
            end
        end 
    end 
    
    private 

    def set_produto
        @empresa_produto = Empresaproduto.find(params[:id])
    end

    # Mensagem amigavel quando o edit nao encontra estoque para o filtro buscado.
    def mensagem_nada_encontrado
        cor = " / cor #{params[:cod_cor]}" if params[:cod_cor].present?
        if params[:format] == "produto"
            termo = params[:id].to_s
            alvo = termo.match?(/\A\d+\z/) ? "o produto #{termo}" : "o nome \"#{termo}\""
            "Nenhum estoque encontrado para #{alvo}#{cor}."
        elsif params[:format] == "compra"
            "Nenhum estoque encontrado para a compra #{params[:id]}."
        else
            "Nenhum estoque encontrado para o código #{params[:id]}."
        end
    end

end
