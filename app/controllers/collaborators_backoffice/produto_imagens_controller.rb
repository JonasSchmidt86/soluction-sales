class CollaboratorsBackoffice::ProdutoImagensController < CollaboratorsBackofficeController

  before_action :set_produto, only: [:create]
  before_action :set_produto_imagem, only: [:destroy, :update_ordem, :toggle_principal]
  
  def index
    if params[:cod_cor].present?
      @produto_imagens = Core.find(params[:cod_cor]).produto_imagens
                        .page(params[:page])
    elsif params[:cod_marca].present?
      @marca = Marca.find_by(cod_marca: params[:cod_marca])
      @produto_imagens = @marca.produto_imagens
                        .page(params[:page])
    elsif params[:cod_grupo].present?
      @grupo = Grupo.find_by(cod_grupo: params[:cod_grupo])
      @produto_imagens = @grupo.produto_imagens
                        .page(params[:page])
    else
      query = params[:term]
      @produto_imagens = ProdutoImagem.joins(:produto)
                        .where('produto_imagens.cod_produto::varchar = REPLACE(TRIM(:query), \'%\', \'\') OR 
                                produto.nome ILIKE :query', query: "%#{query}%")
                        .where(params[:cod_cor].present? ? ["cod_cor = ?", params[:cod_cor]] : nil)
                        .order(:cod_produto, :cod_cor)
                        .page(params[:page])
    end
  end

  def edit
    @produto = params[:id].present? ? Produto.find(params[:id]) : Produto.new
    if params[:id].present? && params[:id] == "0"
      @produto = Produto.new
      @produto_imagens = ProdutoImagem.all.ordenadas
        .page(params[:page])
    elsif params[:id].present?
      if @produto.nil?
        @produto_imagens = ProdutoImagem.all.ordenadas
        .page(params[:page])
      else
        @produto_imagens = @produto.produto_imagens.ordenadas
        .page(params[:page])
      end
    end
  end

  def get_cor_data
    if params[:cod_produto].present? && params[:cod_cor].present?
      empresa_produto = Empresaproduto.where(cod_produto: params[:cod_produto], cod_cor: params[:cod_cor], cod_empresa: current_collaborator.empresa.cod_empresa).first
      if empresa_produto
        render json: {
          descricao: empresa_produto.produto.descricao,
          valor_site: empresa_produto.valor_site,
          publicado: empresa_produto.publicado,
          name: empresa_produto.produto.titulo
        }
      else
        render json: { error: 'Dados não encontrados' }, status: 404
      end
    else
      render json: { error: 'Parâmetros inválidos' }, status: 400
    end
  end
  
  def create
    if params[:cod_cor].present?
      @cor = Core.find(params[:cod_cor])
    else
      @cor = Core.find_by(cod_cor: 1) # Default to first color if not provided
    end
  
    if params[:imagens].present?
      if @produto.blank?
        redirect_to edit_collaborators_backoffice_produto_imagen_path(0,params.to_unsafe_h), notice: 'Produto não encontrado!'
        return
      end
      
      # Atualizar campos na tabela empresaproduto
      if params[:cod_cor].present?
        empresa_produto = Empresaproduto.find_by(cod_produto: @produto.cod_produto, cod_cor: params[:cod_cor], cod_empresa: current_collaborator.empresa.cod_empresa)
        if empresa_produto
          valor_formatado = params[:valor_site].gsub('.', '').gsub(',', '.')   # troca vírgula por ponto
          empresa_produto.valor_site = valor_formatado.to_f

          @produto.descricao = params[:descricao] if params[:descricao].present?
          @produto.titulo = params[:name] if params[:name].present?
          @produto.save!
          empresa_produto.produto = @produto
          empresa_produto.publicado = params[:publicado] == '1' if params[:publicado].present?
          empresa_produto.save!
        end
      end
      
      params[:imagens].each do |imagem|
        next if imagem.blank?

        produto_imagem = ProdutoImagem.new
        produto_imagem.produto = @produto
        produto_imagem.cor = @cor

        nome_imagem = "#{@produto.nome.split(' ')[0..1].join(' ')}_#{imagem.original_filename.split('.').first}.#{imagem.original_filename}"
        
        imagem_processada = MiniMagick::Image.read(imagem.tempfile)
        imagem_processada.resize "1920x1080"

        produto_imagem.imagem.attach(
            io: StringIO.open(imagem_processada.to_blob),
            filename: nome_imagem,
            content_type: imagem.content_type,
            key: nome_imagem
          )

        @produto.produto_imagens << produto_imagem
        produto_imagem.save
      end

      if params[:path].present? 
        path = edit_collaborators_backoffice_produto_imagen_path(@produto.cod_produto)
      else
        path = collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto)
      end

      redirect_to path, notice: 'Imagens associadas ao produto foram salvas com sucesso!'

    else
      redirect_to path, alert: 'Nenhuma imagem foi selecionada!'
    end
  rescue ActiveRecord::Rollback => e
    redirect_to collaborators_backoffice_produto_imagens_path, alert: "Falha ao salvar imagens: #{e.message}"
  end

  def destroy
    @produto_imagem.imagem.purge if @produto_imagem.imagem.attached?

    if params[:term].present?
      path = edit_collaborators_backoffice_produto_imagen_path(@produto_imagem.produto.cod_produto)
    else
      path = collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto)
    end

    if @produto_imagem.destroy
      redirect_to path, notice: "Imagem removida com sucesso!"
    else
      redirect_to path, alert: "Falha ao remover imagem!"
    end
  end
  
  def update_ordem
    if @produto_imagem.update(ordem: params[:ordem])
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  def toggle_principal
    if @produto_imagem.update(principal: !@produto_imagem.principal)
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  private
  
  def set_produto
    if params[:cod_produto].present?
      @produto = Produto.find(params[:cod_produto]);
    end
  end
  
  def set_produto_imagem
    @produto_imagem = ProdutoImagem.find(params[:id]);
    @produto = @produto_imagem.produto;
  end
end