class CollaboratorsBackoffice::ProdutosController < CollaboratorsBackofficeController


    before_action :set_produto, only: [:edit, :update, :destroy, :show, :atualizar_estoque, :desativar_estoque, :ativar_estoque]
    #before_action :get_produto, only: [:new, :edit, :update,]

    def index
        @produtos = Produto.order('cod_produto').all.page(params[:page])
    end
    
    def update
        if @produto.update(params_produto.except(:imagens))
          # Reflete os dados fiscais na fiscal_produto da empresa logada.
          upsert_fiscal_produto(@produto)
          redirect_to collaborators_backoffice_produtos_path, notice: "Produto atualizado com sucesso!"
        else
          render :edit
        end
    end

    # editar para desativar o item para não aparecer mais 
    def edit
    end

    def new
        @produto = Produto.new 
        @produto.cod_produto = Produto.last.cod_produto += 1
    end

    def create
        @produto = Produto.new(params_produto)
        action_message = params[:action_message] || ''

        if @produto.cod_produto.blank?
            ultimo_codigo = Produto.maximum(:cod_produto) || 0
            @produto.cod_produto = ultimo_codigo + 1
        end

        if @produto.save
            # Fiscal por empresa: alem do cadastro global, grava os dados fiscais
            # informados na fiscal_produto da EMPRESA logada (quem cadastrou).
            # Outras empresas criam o seu quando precisarem (importacao/edicao);
            # ate la o fallback le do produto global.
            upsert_fiscal_produto(@produto)

            if action_message == 'Welcome/index'
                redirect_to collaborators_backoffice_welcome_index_path, notice: "Produto Cadastrado com sucesso!"
            else
                redirect_to collaborators_backoffice_produtos_path, notice: "Produto Cadastrado com sucesso!"
            end
        else 
            if action_message == 'Welcome/index'
                redirect_to collaborators_backoffice_welcome_index_path, alert: "Erro ao cadastrar produto!"
            else
                render :new
            end
        end
    end
    
    def remover_imagem
        @produto = Produto.find(params[:id])
        imagem = @produto.imagens.find(params[:imagem_id])  # Encontra a imagem associada ao produto
        imagem.purge  # Remove a imagem
    
        redirect_to collaborators_backoffice_imagens_path, notice: "Imagem removida com sucesso."
    end

    def destroy
        if @produto.itenscompra.blank? && @produto.itensvenda.blank? && @produto.empresaprodutos.blank?
            if @produto.destroy
                redirect_to collaborators_backoffice_produtos_path(page: params[:page]) , notice: "Produto Removido!"
            else
                redirect_to collaborators_backoffice_produtos_path(page: params[:page]) , alert: "Erro ao remover produto!"
            end
        else
            @produto.ativo = false;
            if @produto.save
                redirect_to collaborators_backoffice_produtos_path(page: params[:page]), notice: "Produto foi desativado!"
            else 
                redirect_to collaborators_backoffice_produtos_path(page: params[:page]), alert: "Produto não pode ser removido!"
            end
        end
    end

    def show
    end

    def estoque
        produto = Produto.find(params[:id])
        
        dados = produto.empresaprodutos.where("quantidade <> 0").map do |ep|
            {
            id_empresa: ep.cod_empresa,
            nome_produto: produto.nome,
            cor: "#{ep.cod_cor} - #{ep.cor.nmcor}",
            quantidade: ep.quantidade.to_i
            }
        end
        
        render json: dados
    end

    def atualizar_estoque
        ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.sanitize_sql_array([
                "SELECT * FROM function_update_produto_consulta(?::BIGINT, ?::BIGINT, ?::BIGINT)",
                current_collaborator.cod_empresa,
                params[:id],
                params[:cod_cor]
            ])
        )
        ep = Empresaproduto.find_by(cod_empresa: current_collaborator.cod_empresa, cod_produto: params[:id], cod_cor: params[:cod_cor])
        render json: { estoq_real: ep&.estoq_real.to_i, quantidade: ep&.quantidade.to_i }
    end

    # Desativa (ativo = false) o estoque de uma cor especifica apenas para a empresa logada
    def desativar_estoque
        ep = Empresaproduto.find_by(
            cod_empresa: current_collaborator.cod_empresa,
            cod_produto: params[:id],
            cod_cor: params[:cod_cor]
        )

        if ep.nil?
            render json: { error: "Registro de estoque nao encontrado." }, status: :not_found
            return
        end

        if ep.update(ativo: false)
            render json: { ativo: ep.ativo }
        else
            render json: { error: ep.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
    end

    # Reativa (ativo = true) o estoque de uma cor especifica apenas para a empresa logada
    def ativar_estoque
        ep = Empresaproduto.find_by(
            cod_empresa: current_collaborator.cod_empresa,
            cod_produto: params[:id],
            cod_cor: params[:cod_cor]
        )

        if ep.nil?
            render json: { error: "Registro de estoque nao encontrado." }, status: :not_found
            return
        end

        if ep.update(ativo: true)
            render json: { ativo: ep.ativo }
        else
            render json: { error: ep.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
    end


    private 

    def params_produto
        params.require(:produto).permit(:cod_produto, :nome, :ncm, :ucom, :cfop, :ativo, :cest, :cod_margem, :grupo, :marca, :origem, :gtin, :csosn, :cod_perfil_tributario, imagens: [] )
    end

    # Cria/atualiza a fiscal_produto da EMPRESA logada com os dados fiscais do
    # produto. Chamado no create/update do produto para que o cadastro ja grave
    # o fiscal por empresa (nao so no produto global). So grava os campos que
    # vieram preenchidos no form; os demais ficam como estao (nil -> fallback).
    # So atua quando a empresa logada tem modulo fiscal ativo.
    def upsert_fiscal_produto(produto)
        return unless produto&.persisted?
        return unless respond_to?(:empresa_tem_modulo_fiscal?) && empresa_tem_modulo_fiscal?

        registro = FiscalProduto.find_or_initialize_by(
            cod_empresa: current_collaborator.cod_empresa,
            cod_produto: produto.cod_produto
        )
        registro.ncm    = produto.ncm    if produto.ncm.present?
        registro.cfop   = produto.cfop   if produto.cfop.present?
        registro.cest   = produto.cest   if produto.cest.present?
        registro.origem = produto.origem if produto.origem.present?
        registro.gtin   = produto.gtin   if produto.gtin.present?
        registro.csosn  = produto.csosn  if produto.csosn.present?
        registro.cod_perfil_tributario = produto.cod_perfil_tributario if produto.cod_perfil_tributario.present?
        registro.save! if registro.changed?
    rescue => e
        # Nao derruba o cadastro do produto se a fiscal_produto falhar; loga.
        Rails.logger.error("[Produtos#upsert_fiscal_produto] produto #{produto&.cod_produto}: #{e.class} - #{e.message}")
    end

    def set_produto
        @produto = Produto.find(params[:id])
        # @item_venda = ItemVenda.find(cod_produto: @produto.cod_produto )
        # @produtosEmpresa = EmpresaProduto.where('cod_produto = ' params[:id])
    end
        
end
