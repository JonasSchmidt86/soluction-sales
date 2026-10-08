require "json"
require "securerandom"
require "fileutils"

class CollaboratorsBackoffice::ImportacaoEstoqueFiscalController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  def index
    @perfis = PerfilTributario.ativos.order(:nome)
    draft = carregar_rascunho
    @total_linhas = Array(draft&.dig("linhas")).size
    @linhas_salvas = Array(draft&.dig("linhas")).count { |linha| linha["salvo_em"].present? }
    @linhas = preparar_linhas(draft["linhas"]) if draft
  end

  def importar
    arquivo = params[:arquivo]
    return redirect_to(collaborators_backoffice_importacao_estoque_fiscal_path, alert: "Selecione um arquivo CSV ou XLSX.") if arquivo.blank?
    return redirect_to(collaborators_backoffice_importacao_estoque_fiscal_path, alert: "Arquivo maior que o limite de 20 MB.") if arquivo.size > 20.megabytes

    parsed = Fiscal::ImportacaoEstoquePlanilha.new(
      path: arquivo.path,
      filename: arquivo.original_filename
    ).parse
    token = SecureRandom.hex(16)
    draft = {
      "empresa_id" => current_collaborator.cod_empresa,
      "funcionario_id" => current_collaborator.cod_funcionario,
      "criado_em" => Time.current.iso8601,
      "linhas" => parsed.map do |row|
        row.merge(quantidade: row[:quantidade]&.to_s("F"), erros: row[:erros]).transform_keys(&:to_s)
      end
    }
    salvar_rascunho(token, draft)
    session[:importacao_estoque_fiscal_token] = token

    redirect_to collaborators_backoffice_importacao_estoque_fiscal_path, notice: "Planilha lida. Revise os itens, escolha a cor e salve cada linha individualmente."
  rescue ArgumentError => e
    redirect_to collaborators_backoffice_importacao_estoque_fiscal_path, alert: e.message
  rescue StandardError => e
    Rails.logger.error("[ImportacaoEstoqueFiscal#importar] #{e.class}: #{e.message}")
    redirect_to collaborators_backoffice_importacao_estoque_fiscal_path, alert: "Não foi possível ler a planilha. Confira o formato e os cabeçalhos."
  end

  def salvar_linha
    banco_gravado = false
    draft = carregar_rascunho
    return render json: { erro: "Prévia expirada. Envie a planilha novamente." }, status: :gone if draft.nil?

    linha_index = params[:linha].to_i
    linha = draft["linhas"][linha_index]
    return render json: { erro: "Linha não encontrada na prévia." }, status: :not_found if linha.nil?

    dados = {
      cod_cor: params[:cod_cor],
      nome_produto: params[:nome_produto],
      ncm: params[:ncm],
      cest: params[:cest],
      origem: params[:origem],
      cod_perfil_tributario: params[:cod_perfil_tributario]
    }

    resultado = nil
    ActiveRecord::Base.transaction do
      resultado = processar_linha!(linha, dados)
      raise ActiveRecord::Rollback if resultado[:erro]
    end
    return render json: { erro: resultado[:erro] }, status: resultado[:status] if resultado[:erro]

    banco_gravado = true
    linha["salvo_em"] = Time.current.iso8601
    linha["saldo_qtdfiscal_salvo"] = resultado[:saldo_fiscal]
    salvar_rascunho(session[:importacao_estoque_fiscal_token], draft)

    render json: {
      sucesso: true,
      mensagem: resultado[:mensagem],
      produto_id: resultado[:produto_id],
      cor_id: resultado[:cor_id],
      saldo_fiscal: resultado[:saldo_fiscal]
    }
  rescue StandardError => e
    Rails.logger.error("[ImportacaoEstoqueFiscal#salvar_linha] #{e.class}: #{e.message}")
    mensagem = if banco_gravado
      "Linha gravada, mas não foi possível atualizar o estado da prévia. Recarregue para conferir."
    else
      "Falha ao salvar a linha; a transação foi revertida."
    end
    render json: { erro: mensagem }, status: :unprocessable_entity
  end

  # Salva VARIAS linhas de uma vez (Opção 1 - batch). O front envia os campos
  # editaveis de cada linha pronta; processamos todas numa UNICA transacao e
  # reescrevemos o rascunho UMA vez no final (evita o O(n^2) de reescrever o
  # JSON a cada linha). Cada linha falha isoladamente: erros nao abortam o lote,
  # retornamos o resultado por linha para o front atualizar a tela.
  def salvar_lote
    draft = carregar_rascunho
    return render json: { erro: "Prévia expirada. Envie a planilha novamente." }, status: :gone if draft.nil?

    itens = params[:itens]
    itens = itens.values if itens.respond_to?(:values)
    itens = Array(itens)
    return render json: { erro: "Nenhuma linha para salvar." }, status: :unprocessable_entity if itens.empty?

    resultados = []
    salvos = 0

    itens.each do |item|
      item = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item.to_h
      idx = item["linha"].to_i
      linha = draft["linhas"][idx]
      if linha.nil?
        resultados << { linha: idx, erro: "Linha não encontrada na prévia." }
        next
      end

      dados = {
        cod_cor: item["cod_cor"],
        nome_produto: item["nome_produto"],
        ncm: item["ncm"],
        cest: item["cest"],
        origem: item["origem"],
        cod_perfil_tributario: item["cod_perfil_tributario"]
      }

      resultado = nil
      begin
        ActiveRecord::Base.transaction(requires_new: true) do
          resultado = processar_linha!(linha, dados)
          raise ActiveRecord::Rollback if resultado[:erro]
        end
      rescue StandardError => e
        Rails.logger.error("[ImportacaoEstoqueFiscal#salvar_lote] linha #{idx}: #{e.class}: #{e.message}")
        resultado = { erro: "Falha ao salvar; revertida." }
      end

      if resultado[:erro]
        resultados << { linha: idx, erro: resultado[:erro] }
      else
        linha["salvo_em"] = Time.current.iso8601
        linha["saldo_qtdfiscal_salvo"] = resultado[:saldo_fiscal]
        salvos += 1
        resultados << {
          linha: idx, sucesso: true, mensagem: resultado[:mensagem],
          produto_id: resultado[:produto_id], cor_id: resultado[:cor_id],
          saldo_fiscal: resultado[:saldo_fiscal]
        }
      end
    end

    # Reescreve o rascunho UMA unica vez, com todas as linhas salvas marcadas.
    salvar_rascunho(session[:importacao_estoque_fiscal_token], draft) if salvos.positive?

    render json: { salvos: salvos, total: itens.size, resultados: resultados }
  rescue StandardError => e
    Rails.logger.error("[ImportacaoEstoqueFiscal#salvar_lote] #{e.class}: #{e.message}")
    render json: { erro: "Falha ao processar o lote." }, status: :unprocessable_entity
  end

  # Processa UMA linha dentro de uma transacao ja aberta pelo chamador.
  # Retorna um Hash: em erro { erro:, status: }; em sucesso { mensagem:,
  # produto_id:, cor_id:, saldo_fiscal: }. NAO abre transacao propria nem
  # mexe no rascunho (responsabilidade do chamador), para servir tanto o
  # salvamento individual quanto o lote.
  def processar_linha!(linha, dados)
    return { erro: "Esta linha já foi salva.", status: :conflict } if linha["salvo_em"].present?

    erros_linha = Array(linha["erros"])
    return { erro: erros_linha.join("; "), status: :unprocessable_entity } if erros_linha.any?

    codigo = linha["codigo"].to_s
    return { erro: "Código de produto inválido.", status: :unprocessable_entity } unless codigo.match?(/\A\d+\z/)

    produto = Produto.find_by(cod_produto: codigo.to_i)
    return { erro: "Produto não encontrado pelo código #{codigo}.", status: :not_found } if produto.nil?

    cod_cor = dados[:cod_cor].to_s
    unless cod_cor.match?(/\A\d+\z/)
      return { erro: "Selecione uma cor válida antes de salvar a linha.", status: :unprocessable_entity }
    end

    empresa_produto = Empresaproduto.find_by(
      cod_empresa: current_collaborator.cod_empresa,
      cod_produto: produto.cod_produto,
      cod_cor: cod_cor.to_i
    )
    if empresa_produto.nil?
      cores_disponiveis = Empresaproduto.where(
        cod_empresa: current_collaborator.cod_empresa, cod_produto: produto.cod_produto
      ).distinct.pluck(:cod_cor)
      Rails.logger.warn(
        "[ImportacaoEstoqueFiscal#processar_linha] combinação não encontrada: " \
        "cod_empresa=#{current_collaborator.cod_empresa}, cod_produto=#{produto.cod_produto}, " \
        "cod_cor_recebido=#{cod_cor}, cod_cor_disponiveis=#{cores_disponiveis.inspect}"
      )
      return {
        erro: "A cor #{cod_cor} não está vinculada ao produto #{produto.cod_produto} na empresa atual. " \
              "Cores cadastradas: #{cores_disponiveis.presence&.join(", ") || "nenhuma"}. Recarregue a prévia.",
        status: :unprocessable_entity
      }
    end

    begin
      quantidade = BigDecimal(linha["quantidade"].to_s)
    rescue ArgumentError
      return { erro: "Quantidade inválida na planilha.", status: :unprocessable_entity }
    end

    campos = campos_fiscais_permitidos(produto, dados)
    return { erro: campos[:erro], status: :unprocessable_entity } if campos[:erro]

    nome_produto = dados[:nome_produto].to_s.strip
    return { erro: "Nome do produto não pode ficar vazio.", status: :unprocessable_entity } if nome_produto.blank?
    return { erro: "Nome do produto deve ter no máximo 100 caracteres.", status: :unprocessable_entity } if nome_produto.length > 100
    campos[:alteracoes][:nome] = nome_produto if nome_produto != produto.nome.to_s.strip

    atualizados = []
    produto.with_lock do
      campos[:alteracoes].each do |campo, valor|
        atual = produto.public_send(campo).to_s.strip
        next if atual == valor.to_s

        ProdutoFiscalLog.create!(
          cod_produto: produto.cod_produto,
          cod_empresa: current_collaborator.cod_empresa,
          campo: campo == :cod_perfil_tributario ? "perfil_fiscal" : campo.to_s,
          valor_antigo: atual.presence,
          valor_novo: valor.to_s,
          created_at: Time.current
        )
        atualizados << campo
      end
      produto.update_columns(campos[:alteracoes]) if atualizados.any?
    end

    empresa_produto.with_lock do
      saldo_anterior = empresa_produto.qtdfiscal.to_d
      diferenca = quantidade - saldo_anterior
      if diferenca.nonzero?
        empresa_produto.update_columns(qtdfiscal: quantidade)
        EstoqueLog.create!(
          cod_empresa: empresa_produto.cod_empresa,
          cod_produto: empresa_produto.cod_produto,
          cod_cor: empresa_produto.cod_cor,
          operacao: "IMPORT",
          origem: "AJUSTE",
          quantidade_antes: empresa_produto.quantidade,
          quantidade_movida: 0,
          quantidade_depois: empresa_produto.quantidade,
          qtdfiscal_antes: saldo_anterior,
          qtdfiscal_movida: diferenca,
          qtdfiscal_depois: quantidade,
          usuario: current_collaborator.email.to_s.first(100),
          cod_funcionario: current_collaborator.cod_funcionario,
          origem_sistema: "FISCAL_IMPORT",
          observacao: "Saldo fiscal definido por importação de planilha (linha #{linha["linha_planilha"]})."
        )
      end
    end

    {
      mensagem: "Linha salva. #{atualizados.size} campo(s) fiscal(is) alterado(s); saldo fiscal #{quantidade.to_s("F")}.",
      produto_id: produto.cod_produto,
      cor_id: empresa_produto.cod_cor,
      saldo_fiscal: quantidade.to_s("F")
    }
  end

  def limpar
    token = session.delete(:importacao_estoque_fiscal_token)
    File.delete(caminho_rascunho(token)) if token.present? && File.exist?(caminho_rascunho(token))
    redirect_to collaborators_backoffice_importacao_estoque_fiscal_path, notice: "Prévia removida."
  end

  private

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end

  def carregar_rascunho
    token = session[:importacao_estoque_fiscal_token].to_s
    return nil unless token.match?(/\A[a-f0-9]{32}\z/)

    path = caminho_rascunho(token)
    return nil unless File.file?(path)

    draft = JSON.parse(File.read(path))
    return nil unless draft["empresa_id"].to_i == current_collaborator.cod_empresa.to_i
    return nil unless draft["funcionario_id"].to_i == current_collaborator.cod_funcionario.to_i
    return nil if Time.iso8601(draft["criado_em"]) < 24.hours.ago

    draft
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def salvar_rascunho(token, draft)
    FileUtils.mkdir_p(diretorio_rascunhos)
    limpar_rascunhos_expirados
    File.open(caminho_rascunho(token), File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
      file.write(JSON.generate(draft))
    end
  end

  def preparar_linhas(rows)
    rows = Array(rows).each_with_index.filter_map do |row, draft_index|
      row = row.stringify_keys
      next if row["salvo_em"].present?

      [row.merge("erros" => Array(row["erros"])), draft_index]
    end
    codigos = rows.filter_map do |row|
      row = row.first
      codigo = row["codigo"].to_s
      codigo.to_i if codigo.match?(/\A\d+\z/) && row["erros"].empty?
    end.uniq
    @produtos = Produto.where(cod_produto: codigos).index_by { |produto| produto.cod_produto.to_s }
    @cores_por_produto = Empresaproduto.includes(:cor)
                                      .where(cod_empresa: current_collaborator.cod_empresa, cod_produto: codigos)
                                      .group_by { |ep| ep.cod_produto.to_s }
    rows.map do |row, draft_index|
      cores = @cores_por_produto[row["codigo"].to_s] || []
      row.merge(
        draft_index: draft_index,
        produto: @produtos[row["codigo"].to_s],
        cores: cores,
        # Opção 2: quando o produto tem UMA unica cor na empresa, ja marcamos
        # qual pre-selecionar na tela — elimina a escolha manual na maioria das
        # linhas (caso comum no inventario) e acelera o fluxo humano.
        cor_unica: (cores.size == 1 ? cores.first.cod_cor : nil)
      )
    end.sort_by do |row|
      nome_cadastro = row[:produto]&.nome.to_s.strip
      nome_planilha = row["nome"].to_s.strip
      nome_principal = nome_cadastro.presence || nome_planilha
      [normalizar_nome_ordenacao(nome_principal), normalizar_nome_ordenacao(nome_planilha), row["codigo"].to_s, row["linha_planilha"].to_i]
    end
  end

  def normalizar_nome_ordenacao(nome)
    nome.to_s.unicode_normalize(:nfkd).encode("ASCII", replace: "").downcase.strip
  end

  def campos_fiscais_permitidos(produto, dados = {})
    alteracoes = {}
    ncm = dados[:ncm].to_s.strip
    cest = dados[:cest].to_s.strip
    origem = dados[:origem].to_s.strip
    perfil = dados[:cod_perfil_tributario].to_s.strip

    alteracoes[:ncm] = ncm if ncm.present? && ncm != produto.ncm.to_s.strip
    alteracoes[:cest] = cest if cest.present? && cest != produto.cest.to_s.strip
    alteracoes[:origem] = origem if origem.present? && origem != produto.origem.to_s.strip

    return { erro: "NCM deve conter 8 dígitos." } if alteracoes[:ncm] && !alteracoes[:ncm].match?(/\A\d{8}\z/)
    return { erro: "CEST deve conter 7 dígitos." } if alteracoes[:cest] && !alteracoes[:cest].match?(/\A\d{7}\z/)
    if alteracoes[:origem] && !Fiscal::OrigemProdutoNfeService::ORIGENS_VALIDAS.include?(alteracoes[:origem])
      return { erro: "Origem fiscal inválida." }
    end
    if perfil.present? && PerfilTributario.ativos.where(cod_perfil_tributario: perfil).none?
      return { erro: "Perfil tributário inválido." }
    end

    alteracoes[:cod_perfil_tributario] = perfil.to_i if perfil.present? && perfil.to_i != produto.cod_perfil_tributario.to_i
    { alteracoes: alteracoes }
  end

  def diretorio_rascunhos
    Rails.root.join("storage", "fiscal_estoque_imports").to_s
  end

  def caminho_rascunho(token)
    Rails.root.join("storage", "fiscal_estoque_imports", "#{token}.json").to_s
  end

  def limpar_rascunhos_expirados
    Dir.glob(File.join(diretorio_rascunhos, "*.json")).each do |path|
      File.delete(path) if File.mtime(path) < 24.hours.ago
    rescue Errno::ENOENT
      next
    end
  end
end