class CollaboratorsBackoffice::NotasAvulsasController < CollaboratorsBackofficeController
  before_action :autorizar_fiscal!
  before_action :set_documento, only: [:show, :danfe, :cancelar]

  MODELOS = [55, 65].freeze

  # Lista as notas avulsas (documentos sem venda) da empresa logada.
  def index
    @documentos = DocumentoFiscal
                  .where(cod_empresa: current_collaborator.cod_empresa, cod_venda: nil)
                  .order(cod_documento_fiscal: :desc)
                  .limit(100)
  end

  # Formulario de emissao avulsa. modelo = 55 (NF-e, default) ou 65 (NFC-e).
  def new
    @modelo = modelo_param
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = OperacaoFiscal.find_by(nome: "NF avulsa") || OperacaoFiscal.find_by(nome: "Venda")
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)
    @finalidades = DocumentoFiscal::FINALIDADES
    # Itens re-exibidos quando o create falha (preserva o que o usuario digitou).
    @itens_preenchidos = @itens_preenchidos || []
  end

  # GET .../notas_avulsas/resolver_cfop?cod_produto=&cod_operacao_fiscal=&cod_perfil_tributario=
  # Resolve o CFOP de um item pela regra (perfil + operacao do topo), com destino
  # = UF do destinatario informado (ou UF da empresa). Sem regra, CFOP em branco.
  def resolver_cfop
    empresa  = current_collaborator.empresa
    operacao = OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal])
    produto  = Produto.find_by(cod_produto: params[:cod_produto])
    # Perfil explicito (escolhido na tela) tem prioridade; senao, o do produto.
    perfil   = PerfilTributario.find_by(cod_perfil_tributario: params[:cod_perfil_tributario]) ||
               produto&.perfil_tributario
    destinatario = Pessoa.find_by(cod_pessoa: params[:cod_pessoa])

    # tipo_cliente segue a mesma logica da venda: sem destinatario (ou PF) =
    # consumidor_final; PJ = contribuinte. Fixar "contribuinte" fazia a regra de
    # Venda (consumidor_final) nao casar e o CFOP vir vazio.
    tipo_cliente = if destinatario&.pessoa_juridica? then "contribuinte" else "consumidor_final" end

    cfop = nil
    if operacao && (perfil || produto)
      cfop = Fiscal::CfopResolver.new(empresa: empresa, destino_uf: destinatario&.uf,
                                      tipo_cliente: tipo_cliente)
                                 .cfop(produto, operacao, perfil: perfil)
    end
    render json: {
      cfop:   cfop,
      origem: cfop.present? ? "regra" : "sem_regra",
      # Devolve o perfil do produto para o front pre-selecionar o select.
      cod_perfil_tributario: produto&.cod_perfil_tributario
    }
  rescue => e
    Rails.logger.error("[NotasAvulsas#resolver_cfop] #{e.class} - #{e.message}")
    render json: { cfop: nil, origem: "erro" }
  end

  # Emite a NF avulsa a partir dos itens (e destinatario, se 55).
  def create
    @modelo = modelo_param
    empresa = current_collaborator.empresa
    cliente = resolver_cliente
    itens   = itens_param

    # Validacoes: em erro, RE-EXIBE o form com os dados preenchidos (sem redirect,
    # que recarregava o new vazio e apagava tudo que o usuario digitou).
    if @modelo == 55 && cliente.nil?
      return reexibir_form("NF-e (55) exige um destinatário. Informe o cliente.")
    end
    if itens.empty?
      return reexibir_form("Informe ao menos um produto.")
    end

    operacao = operacao_escolhida

    avulso = Fiscal::DocumentoAvulso.new(empresa: empresa, cliente: cliente, itens: itens)
    documento = Fiscal::EmissorFiscal.new(avulso, modelo: @modelo,
                                          operacao: operacao,
                                          finalidade: params[:finalidade],
                                          cod_funcionario: current_collaborator.cod_funcionario).emitir

    if documento.autorizada?
      redirect_to collaborators_backoffice_notas_avulsa_path(documento),
                  notice: "NF autorizada. Chave: #{documento.chave_acesso}"
    else
      reexibir_form("NF #{documento.status}: #{documento.mensagem_sefaz}")
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    reexibir_form(e.message)
  rescue => e
    Rails.logger.error("[NotasAvulsas#create] #{e.class} - #{e.message}")
    reexibir_form("Falha ao emitir: #{e.message}")
  end

  def show
    # A NF avulsa NAO persiste itens no nosso banco; eles vivem no XML autorizado
    # que a SEFAZ devolveu. Extraimos o resumo (geral + itens) para exibir na tela.
    @resumo = resumo_do_xml(@documento)
  end

  # POST /collaborators_backoffice/notas_avulsas/previsualizar
  # Gera o DANFE/DANFCE de PRE-VISUALIZACAO (sem transmitir a SEFAZ) a partir
  # dos itens/destinatario do formulario, usando a operacao/finalidade escolhidas.
  def previsualizar
    @modelo = modelo_param
    empresa = current_collaborator.empresa
    cliente = resolver_cliente
    itens   = itens_param

    if itens.empty?
      render json: { erro: "Informe ao menos um produto para pré-visualizar." },
             status: :unprocessable_entity
      return
    end

    operacao = operacao_escolhida
    avulso  = Fiscal::DocumentoAvulso.new(empresa: empresa, cliente: cliente, itens: itens)
    preview = Fiscal::EmissorFiscal.new(avulso, modelo: @modelo, operacao: operacao,
                                        finalidade: params[:finalidade],
                                        cod_funcionario: current_collaborator.cod_funcionario)
                                   .pre_visualizar(tipo_arquivo: 1)

    if preview.sucesso?
      # NFC-e (65) devolve o DANFCE em HTML; NF-e (55) em PDF. Serve com o
      # Content-Type real detectado para o navegador renderizar corretamente.
      send_data preview.conteudo,
                filename: "previsualizacao-avulsa-#{@modelo}.#{preview.extensao}",
                type: preview.content_type, disposition: "inline"
    else
      render json: { erro: "Não foi possível pré-visualizar: #{preview.erro}" },
             status: :unprocessable_entity
    end
  rescue Fiscal::EmissorFiscal::DadosFiscaisIncompletos,
         Fiscal::EmissorFiscal::SemConfig,
         Fiscal::EmissorFiscal::SemOperacao => e
    render json: { erro: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("[NotasAvulsas#previsualizar] #{e.class} - #{e.message}")
    render json: { erro: "Falha ao pré-visualizar: #{e.message}" }, status: :unprocessable_entity
  end

  # PDF do DANFE (quando autorizada).
  def danfe
    if @documento.danfe_base64.blank?
      redirect_to collaborators_backoffice_notas_avulsa_path(@documento), alert: "DANFE indisponível."
      return
    end
    conteudo = Base64.decode64(@documento.danfe_base64)
    # NFC-e (modelo 65) tem o DANFCE em HTML; NF-e 55 em PDF. Detecta o formato
    # real pelos primeiros bytes e serve com o Content-Type certo (senao o
    # navegador tenta abrir HTML como PDF e falha).
    tipo, ext = danfe_tipo_extensao(conteudo)
    send_data conteudo,
              filename: "danfe-avulsa-#{@documento.cod_documento_fiscal}.#{ext}",
              type: tipo, disposition: "inline"
  end

  # Cancela a NF avulsa autorizada.
  def cancelar
    @documento.cancelar!(justificativa: params[:justificativa].to_s,
                         cod_funcionario: current_collaborator.cod_funcionario)
    redirect_to collaborators_backoffice_notas_avulsas_path, notice: "NF cancelada."
  rescue ArgumentError => e
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: e.message
  rescue NotImplementedError
    redirect_to collaborators_backoffice_notas_avulsas_path,
                alert: "Cancelamento ainda não implementado para este provedor."
  rescue => e
    Rails.logger.error("[NotasAvulsas#cancelar] doc #{@documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    redirect_to collaborators_backoffice_notas_avulsas_path, alert: "Falha ao cancelar: #{e.message}"
  end

  # Cores de um produto (JSON) para o select de cor no form. Traz tambem a
  # qtdfiscal (estoque FISCAL) e a quantidade (estoque fisico) por cor, para o
  # usuario ver o saldo fiscal disponivel antes de emitir (a NF baixa qtdfiscal).
  def cores_produto
    cores = Core.select("cores.nmcor, cores.cod_cor, empresaproduto.valorvenda, " \
                        "empresaproduto.qtdfiscal, empresaproduto.quantidade")
                .joins(:empresaprodutos)
                .where("empresaproduto.cod_produto = ? and empresaproduto.cod_empresa = ?",
                       params[:cod_produto], current_collaborator.cod_empresa)
                .order(:nmcor, :cod_cor)
    render json: cores.map { |c|
      {
        cod_cor:    c.cod_cor,
        nmcor:      c.nmcor,
        valorvenda: c.valorvenda,
        qtdfiscal:  c.qtdfiscal.to_f,
        quantidade: c.quantidade.to_f
      }
    }
  end

  private

  def set_documento
    @documento = DocumentoFiscal.where(cod_empresa: current_collaborator.cod_empresa, cod_venda: nil)
                                .find(params[:id])
  end

  # Le o XML autorizado (xml_base64) e devolve um Hash com os dados gerais e os
  # itens da nota, para exibir na tela show. nil quando nao ha XML.
  def resumo_do_xml(documento)
    b64 = documento.xml_base64.presence
    return nil if b64.blank?

    xml = Base64.decode64(b64)
    doc = Nokogiri::XML(xml)
    g = ->(xp) { doc.at_xpath(xp)&.text }

    dest_nome = g.call('//*[local-name()="dest"]/*[local-name()="xNome"]')

    itens = doc.xpath('//*[local-name()="det"]').map do |det|
      prod = det.at_xpath('.//*[local-name()="prod"]')
      pg = ->(xp) { prod&.at_xpath(xp)&.text }
      {
        n:      det["nItem"],
        codigo: pg.call('.//*[local-name()="cProd"]'),
        nome:   pg.call('.//*[local-name()="xProd"]'),
        ncm:    pg.call('.//*[local-name()="NCM"]'),
        cfop:   pg.call('.//*[local-name()="CFOP"]'),
        qtd:    pg.call('.//*[local-name()="qCom"]').to_f,
        vun:    pg.call('.//*[local-name()="vUnCom"]').to_f,
        vprod:  pg.call('.//*[local-name()="vProd"]').to_f
      }
    end

    {
      numero:    g.call('//*[local-name()="ide"]/*[local-name()="nNF"]'),
      serie:     g.call('//*[local-name()="ide"]/*[local-name()="serie"]'),
      natureza:  g.call('//*[local-name()="ide"]/*[local-name()="natOp"]'),
      emitida_em: g.call('//*[local-name()="ide"]/*[local-name()="dhEmi"]'),
      destinatario: dest_nome,
      total:     g.call('//*[local-name()="ICMSTot"]/*[local-name()="vNF"]').to_f,
      itens:     itens
    }
  rescue => e
    Rails.logger.error("[NotasAvulsas#resumo_do_xml] doc #{documento.cod_documento_fiscal}: #{e.class} - #{e.message}")
    nil
  end

  # Detecta o Content-Type do arquivo do DANFE/DANFCE pelos primeiros bytes.
  # PDF (NF-e 55) comeca com "%PDF"; DANFCE (NFC-e 65) e HTML.
  def danfe_tipo_extensao(conteudo)
    amostra = conteudo.to_s[0, 64].to_s
    if amostra.start_with?("%PDF")
      ["application/pdf", "pdf"]
    elsif amostra.lstrip.downcase.start_with?("<html", "<!doctype")
      ["text/html", "html"]
    else
      ["application/pdf", "pdf"] # fallback
    end
  end

  def modelo_param
    m = params[:modelo].to_i
    MODELOS.include?(m) ? m : 55
  end

  # Resolve o destinatario: usa cod_pessoa existente (busca) se informado.
  def resolver_cliente
    cod = params[:cod_pessoa].presence
    cod ? Pessoa.find_by(cod_pessoa: cod) : nil
  end

  # Operacao escolhida no topo (fallback: NF avulsa / Venda).
  def operacao_escolhida
    OperacaoFiscal.find_by(cod_operacao_fiscal: params[:cod_operacao_fiscal]) ||
      OperacaoFiscal.find_by(nome: "NF avulsa") ||
      OperacaoFiscal.find_by(nome: "Venda")
  end

  # Re-exibe o form (new) com os dados que o usuario digitou e a mensagem de erro,
  # SEM redirect (que recarregaria o new vazio). Preserva itens/destinatario.
  def reexibir_form(mensagem)
    @operacoes = OperacaoFiscal.ativos.order(:nome)
    @operacao_padrao = operacao_escolhida
    @perfis = PerfilTributario.ativos.de_saida.order(:nome)
    @finalidades = DocumentoFiscal::FINALIDADES
    @finalidade_sel = params[:finalidade]
    @cod_pessoa_sel = params[:cod_pessoa]
    @itens_preenchidos = itens_raw
    flash.now[:alert] = mensagem
    render :new, status: :unprocessable_entity
  end

  # Itens no formato CRU (strings do form), para re-exibir sem perder formatacao.
  def itens_raw
    brutos = params[:itens]
    brutos = brutos.values if brutos.is_a?(ActionController::Parameters)
    Array(brutos).map { |i| i.permit(:cod_produto, :cod_cor, :quantidade, :valorunitario, :cod_perfil_tributario, :cfop, :nome_produto).to_h }
                 .reject { |i| i["cod_produto"].blank? }
  end

  # Monta a lista de itens a partir dos params do form (ja parseada p/ emissao).
  # Espera params[:itens] = [{ cod_produto, cod_cor, quantidade, valorunitario,
  #                            cod_perfil_tributario, cfop }, ...]
  def itens_param
    itens_raw.map do |i|
      {
        cod_produto:           i["cod_produto"],
        cod_cor:               i["cod_cor"],
        quantidade:            MoedaBr.parse(i["quantidade"]),
        valorunitario:         MoedaBr.parse(i["valorunitario"]),
        cod_perfil_tributario: i["cod_perfil_tributario"].presence,
        cfop:                  i["cfop"].presence
      }
    end
  end

  def autorizar_fiscal!
    unless empresa_tem_modulo_fiscal? && access_control.super_admin?
      redirect_to collaborators_backoffice_welcome_index_path, alert: "Acesso negado."
    end
  end
end
