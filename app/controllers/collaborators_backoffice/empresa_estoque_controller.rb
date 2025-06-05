class CollaboratorsBackoffice::EmpresaEstoqueController < CollaboratorsBackofficeController
    
    before_action :set_produto, only: [:destroy, :edit, :update]

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
        @empresa_produto.valorvenda = params[:estoque][:valorvenda].gsub(',', '.').to_f;
        if @empresa_produto.save!
            render json: { message: "Valor atualizado com sucesso!", estoque: @empresa_produto }, status: :ok
          else
            render json: { message: "Erro ao atualizar valor.", errors: @empresa_produto.errors.full_messages }, status: :unprocessable_entity
          end
    end

    def edit 
        # @empresa_produto
        # puts params
        
        if params[:format].present?
            puts params[:format]
            @empresa_produtos = Empresaproduto
                        .where("empresaproduto.cod_produto = ? and empresaproduto.ativo = ? ",params[:id], true)
                .order(cod_produto: :desc, cod_cor: :asc, cod_empresa: :asc ) # Usando símbolo para ordenação
                puts "Passou por aqui!! "
        else

            @empresa_produtos = Empresaproduto
                .joins("INNER JOIN itemcompra ON empresaproduto.cod_produto = itemcompra.cod_produto")
                    .where(itemcompra: { cod_compra: params[:id] }) # Ajuste no filtro
                    .where("empresaproduto.ativo = ? OR empresaproduto.quantidade > ?", true, 0)
                .order(cod_produto: :desc, cod_cor: :asc, cod_empresa: :asc ) # Usando símbolo para ordenação
        end
        # puts @estoque.size;
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

end
