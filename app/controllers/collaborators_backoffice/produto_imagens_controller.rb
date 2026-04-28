class CollaboratorsBackoffice::ProdutoImagensController < CollaboratorsBackofficeController

  before_action :set_produto, only: [:create]
  before_action :set_produto_imagem, only: [:destroy, :update_ordem, :toggle_principal]
  
  def index
    @produto_imagens = ProdutoImagem.distinct.joins(:produto)

    if params[:term].present?
      term = params[:term].strip
      @produto_imagens = @produto_imagens.where(
        "produto.nome ILIKE :q OR produto_imagens.cod_produto::text ILIKE :q",
        q: "%#{term}%")
    end

    if params[:cod_cor].present?
      @produto_imagens = @produto_imagens.where(cod_cor: params[:cod_cor])
    end

    if params[:cod_marca].present?
      @produto_imagens = @produto_imagens.joins(produto: :cod_marca)
                                        .where(produto: { marca: params[:cod_marca] })
    end

    if params[:cod_grupo].present?
      @produto_imagens = @produto_imagens.joins(produto: :grupo)
                                        .where(produto: { grupo: params[:cod_grupo] })
    end

    if params[:publicado].present? && params[:publicado] == '1'
      @produto_imagens = @produto_imagens.joins(produto: :empresaprodutos)
                                        .where(empresaprodutos: { publicado: true })
    end

    @produto_imagens = @produto_imagens.order(:cod_produto, :cod_cor).page(params[:page])
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
      @cor = Core.find_by(cod_cor: 1) # Cor padrão
    end

    if params[:imagens].present?
      if @produto.blank?
        redirect_to edit_collaborators_backoffice_produto_imagen_path(0, params.to_unsafe_h), notice: 'Produto não encontrado!'
        return
      end

      # ---- Atualização de dados do produto e empresa_produto ----
      if params[:cod_cor].present?
        empresa_produto = Empresaproduto.find_by(cod_produto: @produto.cod_produto, cod_cor: params[:cod_cor], cod_empresa: current_collaborator.empresa.cod_empresa)
        if empresa_produto
          valor_formatado = params[:valor_site].gsub('.', '').gsub(',', '.')
          empresa_produto.valor_site = valor_formatado.to_f
          @produto.descricao = params[:descricao] if params[:descricao].present?
          @produto.titulo = params[:name] if params[:name].present?
          @produto.save!
          empresa_produto.produto = @produto
          empresa_produto.publicado = params[:publicado] == '1' if params[:publicado].present?
          empresa_produto.save!
        end
      end
      # ---- Fim atualizações ----

      # ---- Processamento e Salva Imagem ----
      params[:imagens].each do |imagem|
        next if imagem.blank?

        produto_imagem = ProdutoImagem.new
        produto_imagem.produto = @produto
        produto_imagem.cor = @cor

        nome_base = @produto.nome.split(' ')[0..1].join(' ')
        extensao_arquivo = File.extname(imagem.original_filename).downcase
        nome_imagem = "#{nome_base}_#{File.basename(imagem.original_filename, extensao_arquivo)}.jpeg"

        imagem_minimagick = MiniMagick::Image.read(imagem.tempfile)

        # Se for HEIC, converter para JPEG
        if imagem.content_type == 'image/heic' || extensao_arquivo == '.heic'
          imagem_minimagick.format 'jpeg'
        end

        # Redimensiona para o padrão desejado
        imagem_minimagick.resize "1920x1080"

        produto_imagem.imagem.attach(
          io: StringIO.new(imagem_minimagick.to_blob),
          filename: nome_imagem,
          content_type: 'image/jpeg'
        )
        @produto.produto_imagens << produto_imagem
        produto_imagem.save
      end
      # ---- Fim processamento ----

      path = if params[:path].present?
              edit_collaborators_backoffice_produto_imagen_path(@produto.cod_produto)
            else
              collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto)
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