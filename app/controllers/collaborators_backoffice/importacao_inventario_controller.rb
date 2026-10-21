require "json"
require "securerandom"
require "fileutils"

# Importacao de INVENTARIO fiscal (fluxo simplificado, por PRODUTO, sem cor).
# Fluxo: upload -> analisar (parse + classifica) -> tela com RESUMO e so os
# pendentes -> importar os PRONTOS em lote + divergentes selecionados -> grava
# fiscal_produto.qtd_fiscal e empresaproduto.qtdfiscal (cor 1). Nao toca o
# estoque fisico. Produtos nao cadastrados tem botao de cadastro rapido.
class CollaboratorsBackoffice::ImportacaoInventarioController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!

  def index
    draft = carregar_rascunho
    @resultados = draft ? reclassificar(draft) : []
    @resumo = resumir(@resultados)
  end

  # Recebe a planilha, parseia, classifica e guarda o rascunho. Redireciona para
  # o index que mostra o resumo e os pendentes.
  def analisar
    arquivo = params[:arquivo]
    return redirect_to(collaborators_backoffice_importacao_inventario_path, alert: "Selecione um arquivo CSV ou XLSX.") if arquivo.blank?
    return redirect_to(collaborators_backoffice_importacao_inventario_path, alert: "Arquivo maior que 20 MB.") if arquivo.size > 20.megabytes

    linhas = Fiscal::ImportacaoInventarioPlanilha.new(
      path: arquivo.path, filename: arquivo.original_filename
    ).parse

    token = SecureRandom.hex(16)
    draft = {
      "empresa_id" => current_collaborator.cod_empresa,
      "funcionario_id" => current_collaborator.cod_funcionario,
      "criado_em" => Time.current.iso8601,
      "linhas" => linhas.map { |l|
        l.merge(
          quantidade: l[:quantidade]&.to_s("F"),
          valor_unitario: l[:valor_unitario]&.to_s("F"),
          valor_venda: l[:valor_venda]&.to_s("F")
        ).transform_keys(&:to_s)
      } # unidade_medida ja e string; vai no merge original das chaves
    }
    salvar_rascunho(token, draft)
    session[:importacao_inventario_token] = token

    redirect_to collaborators_backoffice_importacao_inventario_path,
                notice: "Planilha lida: #{linhas.size} linhas. Confira o resumo e importe."
  rescue ArgumentError => e
    redirect_to collaborators_backoffice_importacao_inventario_path, alert: e.message
  rescue => e
    Rails.logger.error("[ImportacaoInventario#analisar] #{e.class}: #{e.message}")
    redirect_to collaborators_backoffice_importacao_inventario_path, alert: "Não foi possível ler a planilha. Confira o formato e os cabeçalhos."
  end

  # Importa em lote: recebe os codigos a aplicar (prontos + divergentes que o
  # usuario confirmou). Aplica cada um numa sub-transacao; erros nao abortam o
  # lote. Marca as linhas aplicadas no rascunho.
  def importar
    draft = carregar_rascunho
    return render(json: { erro: "Prévia expirada. Envie a planilha novamente." }, status: :gone) if draft.nil?

    codigos = Array(params[:codigos]).map(&:to_s)
    return render(json: { erro: "Nenhum item para importar." }, status: :unprocessable_entity) if codigos.empty?

    por_codigo = draft["linhas"].index_by { |l| l["codigo"].to_s }
    aplicador = Fiscal::AplicadorInventario.new(
      cod_empresa: current_collaborator.cod_empresa,
      cod_funcionario: current_collaborator.cod_funcionario,
      usuario: current_collaborator.email
    )

    aplicados = 0
    resultados = []
    codigos.each do |codigo|
      linha = por_codigo[codigo]
      if linha.nil?
        resultados << { codigo: codigo, ok: false, erro: "Linha não encontrada." }
        next
      end
      if linha["aplicado_em"].present?
        resultados << { codigo: codigo, ok: false, erro: "Já importado." }
        next
      end

      r = { ok: false, erro: "Falha." }
      begin
        ActiveRecord::Base.transaction(requires_new: true) do
          r = aplicador.aplicar!(
            codigo: codigo.to_i,
            quantidade: BigDecimal(linha["quantidade"].to_s),
            ncm: linha["ncm"],
            valor_unitario: linha["valor_unitario"],
            valor_venda: linha["valor_venda"],
            unidade_medida: linha["unidade_medida"]
          )
          raise ActiveRecord::Rollback unless r[:ok]
        end
      rescue => e
        Rails.logger.error("[ImportacaoInventario#importar] #{codigo}: #{e.class}: #{e.message}")
        r = { ok: false, erro: "Falha ao importar; revertida." }
      end

      if r[:ok]
        linha["aplicado_em"] = Time.current.iso8601
        aplicados += 1
        resultados << { codigo: codigo, ok: true, saldo: r[:saldo] }
      else
        resultados << { codigo: codigo, ok: false, erro: r[:erro] }
      end
    end

    salvar_rascunho(session[:importacao_inventario_token], draft) if aplicados.positive?
    render json: { aplicados: aplicados, total: codigos.size, resultados: resultados }
  rescue => e
    Rails.logger.error("[ImportacaoInventario#importar] #{e.class}: #{e.message}")
    render json: { erro: "Falha ao processar o lote." }, status: :unprocessable_entity
  end

  # Cadastro rapido de produto novo (codigo nao existia): cria produto +
  # empresaproduto (cor 1) e ja aplica o inventario (fiscal_produto/qtdfiscal).
  def cadastrar
    draft = carregar_rascunho
    return render(json: { erro: "Prévia expirada." }, status: :gone) if draft.nil?

    # Identifica a linha pela posicao (linha_planilha) — o codigo pode estar
    # vazio nessa linha (sera informado ou gerado).
    linha_planilha = params[:linha_planilha].to_s
    linha = draft["linhas"].find { |l| l["linha_planilha"].to_s == linha_planilha }
    return render(json: { erro: "Linha não encontrada." }, status: :not_found) if linha.nil?

    nome = params[:nome].to_s.strip
    return render(json: { erro: "Informe o nome do produto." }, status: :unprocessable_entity) if nome.blank?
    return render(json: { erro: "Nome deve ter no máximo 100 caracteres." }, status: :unprocessable_entity) if nome.length > 100

    # Codigo: usa o informado pelo usuario; se vazio, GERA o proximo (mesmo
    # padrao do cadastro de produto: max(cod_produto)+1).
    codigo_informado = params[:codigo].to_s.strip
    if codigo_informado.present? && !codigo_informado.match?(/\A\d+\z/)
      return render(json: { erro: "Código deve ser numérico (ou deixe vazio para gerar)." }, status: :unprocessable_entity)
    end

    ncm = linha["ncm"].to_s.strip
    saldo = nil
    cod_final = nil
    ActiveRecord::Base.transaction do
      cod_final =
        if codigo_informado.present?
          return render(json: { erro: "Produto #{codigo_informado} já existe." }, status: :conflict) if Produto.exists?(cod_produto: codigo_informado.to_i)
          codigo_informado.to_i
        else
          (Produto.maximum(:cod_produto) || 0) + 1
        end

      # grupo 1 / marca 1 = padroes de referencia (o model Produto exige marca
      # e grupo). Ajustaveis depois no cadastro normal do produto.
      Produto.create!(
        cod_produto: cod_final, nome: nome, grupo: 1, marca: 1, ativo: true,
        ncm: (ncm if ncm.match?(/\A\d{8}\z/)),
        ucom: linha["unidade_medida"].to_s.strip.first(8).presence
      )
      r = Fiscal::AplicadorInventario.new(
        cod_empresa: current_collaborator.cod_empresa,
        cod_funcionario: current_collaborator.cod_funcionario,
        usuario: current_collaborator.email
      ).aplicar!(
        codigo: cod_final, quantidade: BigDecimal(linha["quantidade"].to_s), ncm: ncm,
        valor_unitario: linha["valor_unitario"], valor_venda: linha["valor_venda"],
        unidade_medida: linha["unidade_medida"]
      )
      raise ActiveRecord::Rollback unless r[:ok]
      saldo = r[:saldo]
    end
    return render(json: { erro: "Não foi possível cadastrar/importar." }, status: :unprocessable_entity) if saldo.nil?

    linha["aplicado_em"] = Time.current.iso8601
    salvar_rascunho(session[:importacao_inventario_token], draft)
    render json: { ok: true, codigo: cod_final, nome: nome, saldo: saldo }
  rescue ActiveRecord::RecordInvalid => e
    render json: { erro: "Cadastro inválido: #{e.record.errors.full_messages.to_sentence}" }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("[ImportacaoInventario#cadastrar] #{e.class}: #{e.message}")
    render json: { erro: "Falha ao cadastrar o produto." }, status: :unprocessable_entity
  end

  # Remove UMA linha da previa (apenas visual — nao grava nada). Identifica pela
  # linha_planilha. Util para descartar produtos que nao serao importados
  # (ex.: itens de assistencia com codigo invalido).
  def excluir_linha
    draft = carregar_rascunho
    return render(json: { erro: "Prévia expirada." }, status: :gone) if draft.nil?

    linha_planilha = params[:linha_planilha].to_s
    antes = draft["linhas"].size
    draft["linhas"].reject! { |l| l["linha_planilha"].to_s == linha_planilha && l["aplicado_em"].blank? }
    return render(json: { erro: "Linha não encontrada." }, status: :not_found) if draft["linhas"].size == antes

    salvar_rascunho(session[:importacao_inventario_token], draft)
    render json: { ok: true }
  rescue => e
    Rails.logger.error("[ImportacaoInventario#excluir_linha] #{e.class}: #{e.message}")
    render json: { erro: "Falha ao excluir a linha." }, status: :unprocessable_entity
  end

  def limpar
    token = session.delete(:importacao_inventario_token)
    File.delete(caminho_rascunho(token)) if token.present? && File.exist?(caminho_rascunho(token))
    redirect_to collaborators_backoffice_importacao_inventario_path, notice: "Prévia removida."
  end

  private

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end

  # Reclassifica as linhas AINDA NAO aplicadas do rascunho (status atual do banco).
  def reclassificar(draft)
    pendentes = Array(draft["linhas"]).reject { |l| l["aplicado_em"].present? }
    linhas = pendentes.map do |l|
      {
        linha_planilha: l["linha_planilha"], codigo: l["codigo"], nome: l["nome"],
        ncm: l["ncm"], quantidade: (BigDecimal(l["quantidade"].to_s) rescue nil),
        unidade_medida: l["unidade_medida"],
        valor_unitario: (BigDecimal(l["valor_unitario"].to_s) rescue nil),
        valor_venda: (BigDecimal(l["valor_venda"].to_s) rescue nil),
        erros: Array(l["erros"])
      }
    end
    Fiscal::ClassificadorInventario.new(
      cod_empresa: current_collaborator.cod_empresa, linhas: linhas
    ).classificar
  end

  def resumir(resultados)
    {
      total: resultados.size,
      prontos: resultados.count { |r| r.status == :pronto },
      divergentes: resultados.count { |r| r.status == :ncm_divergente },
      novos: resultados.count { |r| r.status == :nao_cadastrado },
      erros: resultados.count { |r| r.status == :erro }
    }
  end

  def carregar_rascunho
    token = session[:importacao_inventario_token].to_s
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
    File.open(caminho_rascunho(token), File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |f|
      f.write(JSON.generate(draft))
    end
  end

  def diretorio_rascunhos
    Rails.root.join("storage", "fiscal_inventario_imports").to_s
  end

  def caminho_rascunho(token)
    Rails.root.join("storage", "fiscal_inventario_imports", "#{token}.json").to_s
  end
end
