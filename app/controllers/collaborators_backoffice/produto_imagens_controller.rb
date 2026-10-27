class CollaboratorsBackoffice::ProdutoImagensController < CollaboratorsBackofficeController

  before_action :set_produto, only: [:create]
  before_action :set_produto_imagem, only: [:destroy, :update_ordem, :toggle_principal]
  
  # POST — salva foto do orçamento na biblioteca do produto
  def salvar_da_orcamento
    produto = Produto.find(params[:cod_produto])
    cor     = Core.find(params[:cod_cor])

    resultado = ProdutoImagemUploadService.call(produto: produto, cor: cor, arquivo: params[:foto])

    if resultado.sucesso?
      render json: { success: true }
    else
      status = params[:foto].blank? ? :bad_request : :unprocessable_entity
      render json: { success: false, error: resultado.erro }, status: status
    end
  end

  # GET para o modal da biblioteca no editor de orçamento
  def biblioteca
    @produto_imagens = ProdutoImagem
      .joins(:imagem_attachment => :blob)
      .where(active_storage_blobs: { service_name: "produtos_storage" })
      .includes(:produto)

    if params[:term].present?
      @produto_imagens = @produto_imagens
        .joins(:produto)
        .where("produto.nome ILIKE :q", q: "%#{params[:term].strip}%")
    end

    @produto_imagens = @produto_imagens.order(:cod_produto).page(params[:page]).per(24)

    # Filtrar apenas os que têm arquivo físico no disco
    @produto_imagens = @produto_imagens.select do |img|
      begin
        blob = img.imagem.blob
        path = blob.service.send(:path_for, blob.key)
        File.exist?(path)
      rescue
        false
      end
    end

    render partial: "biblioteca_modal", locals: { produto_imagens: @produto_imagens }
  end

  def index
    @produto_imagens = ProdutoImagem.distinct.joins(:produto)

    if params[:term].present?
      term = params[:term].strip
      @produto_imagens = @produto_imagens.where(
        "produto.nome ILIKE :q OR produto_imagens.cod_produto::text ILIKE :q",
        q: "%#{term}%")
    end

    if params[:cod_produto].present?
      @produto_imagens = @produto_imagens.where(produto_imagens: { cod_produto: params[:cod_produto] })
    end

    if params[:cod_cor].present?
      @produto_imagens = @produto_imagens.where(cod_cor: params[:cod_cor])
    end

    if params[:cod_marca].present?
      @produto_imagens = @produto_imagens.joins(produto: :cod_marca)
                                        .where(produto: { marca: params[:cod_marca] })
    end

    if params[:cod_grupo].present?
      @produto_imagens = @produto_imagens.joins(produto: :cod_grupo)
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
        @cod_cor_selecionada = cor_pre_selecionada(@produto)
      end
    end
  end

  # GET — tela de cadastro rápido: seleciona várias imagens e, para cada uma,
  # escolhe produto (busca por código/nome), cor e descrição.
  def cadastro_rapido
  end

  # GET (AJAX) — busca de produtos para o modo EDIÇÃO do cadastro rápido.
  # Diferente da busca genérica, retorna APENAS produtos que já possuem imagem
  # cadastrada (produto_imagens), pois só esses fazem sentido editar aqui.
  # Aceita código exato ou nome (ILIKE, com curinga % no termo). Espera: query.
  def cadastro_rapido_buscar
    query = params[:query].to_s.strip
    return render(json: []) if query.blank?

    cod_empresa = current_collaborator.empresa.cod_empresa

    produtos = Produto
      .where("cod_produto IN (SELECT DISTINCT cod_produto FROM produto_imagens)")
      .where("cod_produto::varchar = REPLACE(TRIM(:q), '%', '') OR nome ILIKE :q", q: "%#{query}%")

    # Filtro por publicação (empresaproduto.publicado, por cor desta empresa).
    # publicadas     = tem ao menos uma cor publicada
    # nao_publicadas = não tem nenhuma cor publicada
    publicados_sql = "SELECT DISTINCT cod_produto FROM empresaproduto WHERE cod_empresa = #{cod_empresa.to_i} AND publicado = true"
    case params[:publicado].to_s
    when 'publicadas'
      produtos = produtos.where("cod_produto IN (#{publicados_sql})")
    when 'nao_publicadas'
      produtos = produtos.where("cod_produto NOT IN (#{publicados_sql})")
    end

    produtos = produtos
      .select(:cod_produto, :nome)
      .order(:nome)
      .limit(50)
      .map { |p| { cod_produto: p.cod_produto, produto: "#{p.cod_produto} - #{p.nome}" } }

    render json: produtos
  end

  # GET (AJAX) — carrega um produto já cadastrado para EDIÇÃO no cadastro rápido.
  # Retorna os dados do produto (título/descrição), as cores com estoque e o
  # estado de "publicado" por cor, além de todas as imagens já cadastradas
  # (id, url, cod_cor, ordem). Espera: cod_produto.
  def cadastro_rapido_produto
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render(json: { error: 'Produto não encontrado' }, status: :not_found) if produto.nil?

    cod_empresa = current_collaborator.empresa.cod_empresa

    # Cores do produto nesta empresa (+ fallback cor 1 quando não houver).
    cores = Core.select(:nmcor, :cod_cor)
                .joins(:empresaprodutos)
                .where("empresaproduto.cod_produto = ? AND empresaproduto.cod_empresa = ?", produto.cod_produto, cod_empresa)
                .order(:cod_cor)
                .map { |c| { cod_cor: c.cod_cor, nmcor: c.nmcor } }
    cores = [{ cod_cor: 1, nmcor: (Core.find_by(cod_cor: 1)&.nmcor || 'Padrão') }] if cores.blank?

    publicado_por_cor = Empresaproduto
                        .where(cod_produto: produto.cod_produto, cod_empresa: cod_empresa)
                        .pluck(:cod_cor, :publicado)
                        .to_h

    # Cor que deve vir selecionada ao abrir: a primeira cor PUBLICADA (entre as
    # cores listadas). Se nenhuma estiver publicada, cai na primeira cor da lista.
    codigos_cor = cores.map { |c| c[:cod_cor] }
    cod_cor_selecionada = codigos_cor.find { |cc| publicado_por_cor[cc] } || codigos_cor.first

    imagens = produto.produto_imagens.ordenadas.map do |img|
      {
        id: img.id,
        cod_cor: img.cod_cor,
        ordem: img.ordem,
        principal: img.principal,
        url: (rails_blob_path(img.imagem, only_path: true) if img.imagem.attached?)
      }
    end

    render json: {
      cod_produto: produto.cod_produto,
      nome: produto.nome,
      titulo: produto.titulo,
      descricao: produto.descricao,
      cores: cores,
      publicado_por_cor: publicado_por_cor,
      cod_cor_selecionada: cod_cor_selecionada,
      imagens: imagens
    }
  end

  # POST (AJAX) — salva os dados editáveis de um produto já cadastrado:
  # título e descrição (no produto) e publicado (no empresaproduto da cor).
  # Espera: cod_produto, cod_cor, titulo, descricao, publicado.
  def cadastro_rapido_salvar_dados
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render(json: { success: false, error: 'Produto não encontrado' }, status: :not_found) if produto.nil?

    produto.descricao = params[:descricao] if params.key?(:descricao)
    produto.titulo    = params[:titulo]    if params.key?(:titulo)
    produto.save if produto.changed?

    aplicar_publicado(produto, params[:cod_cor], params[:publicado]) if params[:cod_cor].present? && params.key?(:publicado)

    render json: { success: true }
  rescue => e
    Rails.logger.warn "[CadastroRapido] Falha ao salvar dados: #{e.message}"
    render json: { success: false, error: 'Falha ao salvar' }, status: :internal_server_error
  end

  # POST (AJAX) — apaga TODAS as imagens de um produto de uma vez (ação em lote).
  # Remove os anexos (purge) e destrói os registros produto_imagem. Espera: cod_produto.
  def cadastro_rapido_apagar_todas
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    return render(json: { success: false, error: 'Produto não encontrado' }, status: :not_found) if produto.nil?

    imagens = produto.produto_imagens.to_a
    removidas = 0

    imagens.each do |img|
      img.imagem.purge if img.imagem.attached?
      removidas += 1 if img.destroy
    end

    # Produto sem imagem não deve ficar publicado: despublica todas as cores
    # desse produto na empresa logada.
    Empresaproduto
      .where(cod_produto: produto.cod_produto, cod_empresa: current_collaborator.empresa.cod_empresa)
      .update_all(publicado: false)

    render json: { success: true, removidas: removidas }
  rescue => e
    Rails.logger.warn "[CadastroRapido] Falha ao apagar todas as imagens: #{e.message}"
    render json: { success: false, error: 'Falha ao apagar' }, status: :internal_server_error
  end

  # POST — salva em lote. Recebe uma linha por imagem:
  #   itens[<i>][arquivo], itens[<i>][cod_produto], itens[<i>][cod_cor], itens[<i>][descricao]
  def cadastro_rapido_salvar
    itens = params[:itens]

    if itens.blank?
      redirect_to cadastro_rapido_collaborators_backoffice_produto_imagens_path,
                  alert: 'Nenhuma imagem foi enviada!'
      return
    end

    salvas = 0
    erros  = []

    itens.each_value do |item|
      arquivo = item[:arquivo]
      next if arquivo.blank?

      produto = Produto.find_by(cod_produto: item[:cod_produto])
      if produto.nil?
        erros << "Selecione um produto para todas as imagens."
        next
      end

      cor = if item[:cod_cor].present?
              Core.find_by(cod_cor: item[:cod_cor])
            end
      cor ||= Core.find_by(cod_cor: 1)

      # Atualiza descrição e título no próprio produto.
      produto.descricao = item[:descricao] if item[:descricao].present?
      produto.titulo    = item[:titulo]    if item[:titulo].present?
      produto.save if produto.changed?

      # Publicar direto (empresaproduto.publicado) para a cor efetivamente usada.
      aplicar_publicado(produto, cor&.cod_cor, item[:publicado]) if item.key?(:publicado)

      resultado = ProdutoImagemUploadService.call(produto: produto, cor: cor, arquivo: arquivo)

      if resultado.sucesso?
        salvas += 1
      else
        erros << "#{produto.nome}: #{resultado.erro}"
      end
    end

    if salvas.positive? && erros.empty?
      redirect_to cadastro_rapido_collaborators_backoffice_produto_imagens_path,
                  notice: "#{salvas} imagem(ns) cadastrada(s) com sucesso!"
    elsif salvas.positive?
      redirect_to cadastro_rapido_collaborators_backoffice_produto_imagens_path,
                  alert: "#{salvas} salva(s). Falhas: #{erros.uniq.join(' | ')}"
    else
      redirect_to cadastro_rapido_collaborators_backoffice_produto_imagens_path,
                  alert: "Nenhuma imagem foi salva. #{erros.uniq.join(' | ')}"
    end
  end

  # POST (AJAX) — verifica se a imagem já existe para o produto (sem gravar).
  # Espera: cod_produto, arquivo. Responde { duplicada: true/false }.
  def cadastro_rapido_verificar
    produto = Produto.find_by(cod_produto: params[:cod_produto])

    if produto.nil? || params[:arquivo].blank?
      render json: { duplicada: false }
      return
    end

    duplicada = ProdutoImagemUploadService.duplicada?(produto: produto, arquivo: params[:arquivo])
    render json: { duplicada: duplicada }
  end

  # POST (AJAX) — grava UMA imagem (uma linha da tabela de cadastro rápido).
  # Espera: cod_produto, cod_cor, arquivo, descricao (opcional), forcar (opcional)
  def cadastro_rapido_linha
    produto = Produto.find_by(cod_produto: params[:cod_produto])
    cor     = Core.find_by(cod_cor: params[:cod_cor])

    if produto.nil? || cor.nil?
      render json: { success: false, error: 'Selecione produto e cor.' }, status: :unprocessable_entity
      return
    end

    if params[:arquivo].blank?
      render json: { success: false, error: 'Nenhuma imagem enviada.' }, status: :bad_request
      return
    end

    produto.descricao = params[:descricao] if params[:descricao].present?
    produto.titulo    = params[:titulo]    if params[:titulo].present?
    produto.save if produto.changed?

    # Publicar direto (empresaproduto.publicado) para a cor efetivamente usada.
    aplicar_publicado(produto, cor.cod_cor, params[:publicado]) if params.key?(:publicado)

    forcar    = params[:forcar].to_s == '1' || params[:forcar].to_s == 'true'
    resultado = ProdutoImagemUploadService.call(produto: produto, cor: cor, arquivo: params[:arquivo], forcar: forcar)

    if resultado.sucesso?
      render json: { success: true }
    else
      render json: { success: false, duplicada: resultado.duplicada?, error: resultado.erro },
             status: :unprocessable_entity
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

      # Após salvar, redireciona sempre para a listagem com todas as imagens
      # do produto (index), e não de volta para a tela de editar.
      redirect_to collaborators_backoffice_produto_imagens_path(cod_produto: @produto.cod_produto),
                  notice: 'Imagens associadas ao produto foram salvas com sucesso!'

    else
      redirect_to edit_collaborators_backoffice_produto_imagen_path(@produto.cod_produto),
                  alert: 'Nenhuma imagem foi selecionada!'
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

  # Aplica o "publicado" no empresaproduto da cor informada, para a empresa logada.
  # Quando ainda NÃO existe empresaproduto para essa combinação produto+cor+empresa,
  # cria o registro (com os campos mínimos) para que a publicação não se perca.
  # valor aceita '1'/'true' (publica) ou '0'/'false' (despublica).
  def aplicar_publicado(produto, cod_cor, valor)
    return if cod_cor.blank?

    cod_empresa = current_collaborator.empresa.cod_empresa

    empresa_produto = Empresaproduto.find_or_initialize_by(
      cod_produto: produto.cod_produto,
      cod_cor: cod_cor,
      cod_empresa: cod_empresa
    )

    # Garante ativo=true ao criar (default do banco é true, mas deixamos explícito
    # para o caso de registro novo recém-inicializado).
    empresa_produto.ativo = true if empresa_produto.new_record?

    publicar = valor.to_s == '1' || valor.to_s == 'true'
    empresa_produto.publicado = publicar
    empresa_produto.save
  end

  # Define a cor que deve vir pré-selecionada no select ao abrir o editar:
  #   1) se alguma cor do produto (nesta empresa) está marcada como publicada,
  #      usa a primeira publicada (por cod_cor);
  #   2) senão, se o produto tem apenas UMA cor cadastrada, usa essa única.
  # Retorna nil quando há várias cores e nenhuma publicada (mantém o prompt).
  def cor_pre_selecionada(produto)
    escopo = Empresaproduto.where(
      cod_produto: produto.cod_produto,
      cod_empresa: current_collaborator.cod_empresa
    )

    publicada = escopo.where(publicado: true).order(:cod_cor).limit(1).pick(:cod_cor)
    return publicada if publicada.present?

    cores = escopo.distinct.pluck(:cod_cor)
    cores.first if cores.size == 1
  end

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