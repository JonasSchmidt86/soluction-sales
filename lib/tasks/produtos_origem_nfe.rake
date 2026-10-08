namespace :produtos do
  desc "Atualiza origem fiscal dos produtos a partir de NF-e de compra (DRY-RUN; APPLY=1 grava)"
  task atualizar_origem_nfe: :environment do
    apply = ENV["APPLY"].to_s == "1"
    relatorio = Fiscal::OrigemProdutoNfeService.new.executar(apply: apply)
    produtos = relatorio[:produtos]
    campos = Fiscal::OrigemProdutoNfeService::CAMPOS_FISCAIS
    rotulos_campos = {
      origem: "origem",
      ncm: "NCM",
      cest: "CEST",
      gtin: "GTIN",
      ucom: "UCOM"
    }
    rotulos_acoes = {
      atualizar: "ATUALIZAR",
      atualizado: "ATUALIZADO",
      conflito_nf_mais_recente: "CONFLITO NA NF MAIS RECENTE",
      ja_correto: "JÁ CORRETO",
      divergencia_cadastro: "DIVERGÊNCIA DE CADASTRO",
      sem_fonte: "SEM VALOR NA NF MAIS RECENTE",
      fonte_invalida: "VALOR INVÁLIDO NA NF MAIS RECENTE",
      rollback: "ROLLBACK"
    }
    formatar = ->(valor) { valor.blank? ? "(vazio)" : valor }
    fonte_legivel = lambda do |fonte|
      next "(sem referência)" unless fonte
      data = fonte[:data_emissao]&.strftime("%d/%m/%Y %H:%M:%S") || "(data ausente)"
      "NF=#{fonte[:numero_nf] || "(sem número)"} | data=#{data} | chave=#{fonte[:chave_nf]} | fornecedor=#{fonte[:fornecedor]} | cProd=#{fonte[:cprod]} | nItem=#{fonte[:nitem]}"
    end

    puts "Modo: #{relatorio[:modo]}"
    puts "XMLs: total=#{relatorio[:xmls_total]} analisados=#{relatorio[:xmls_analisados]} válidos=#{relatorio[:xmls_validos]} inválidos=#{relatorio[:xmls_invalidos]} ignorados=#{relatorio[:xmls_ignorados]}"
    produtos_auditaveis = produtos.values.select do |item|
      item[:ocorrencias].any? && item[:vinculos_ambiguos].empty?
    end
    atualizaveis = produtos_auditaveis.count { |item| item[:elegivel] }
    corretos = produtos_auditaveis.count do |item|
      fontes_validas = item[:campos].values.select { |campo| campo[:sugerido].present? }
      fontes_validas.any? && fontes_validas.all? { |campo| campo[:acao] == :ja_correto } &&
        item[:campos].values.none? { |campo| %i[atualizar divergencia_cadastro fonte_invalida].include?(campo[:acao]) } &&
        item[:conflitos_historicos].empty?
    end
    divergentes = produtos_auditaveis.count { |item| item[:campos].values.any? { |campo| campo[:acao] == :divergencia_cadastro } }
    divergentes_ambiguos = produtos.values.count do |item|
      item[:ocorrencias].any? && item[:vinculos_ambiguos].any? &&
        item[:campos].values.any? { |campo| campo[:acao] == :divergencia_cadastro }
    end
    conflitos_historicos = produtos.values.count { |item| item[:ocorrencias].any? && item[:conflitos_historicos].any? }
    puts "Produtos: elegíveis=#{atualizaveis} já com dados corretos=#{corretos} com divergência de cadastro segura=#{divergentes} divergências em produto com vínculo ambíguo=#{divergentes_ambiguos} com conflito histórico=#{conflitos_historicos}"
    campos.each do |campo|
      atualizacoes_do_campo = produtos_auditaveis.count do |item|
        %i[atualizar atualizado].include?(item[:campos].dig(campo, :acao))
      end
      corretos_do_campo = produtos_auditaveis.count { |item| item[:campos].dig(campo, :acao) == :ja_correto }
      divergencias_do_campo = produtos_auditaveis.count { |item| item[:campos].dig(campo, :acao) == :divergencia_cadastro }
      conflitos_nf_mais_recente = produtos_auditaveis.count do |item|
        item[:campos].dig(campo, :acao) == :conflito_nf_mais_recente
      end
      divergencias_ambiguas_do_campo = produtos.values.count do |item|
        item[:ocorrencias].any? && item[:vinculos_ambiguos].any? && item[:campos].dig(campo, :acao) == :divergencia_cadastro
      end
      sem_fonte_do_campo = produtos_auditaveis.count do |item|
        %i[sem_fonte fonte_invalida].include?(item[:campos].dig(campo, :acao))
      end
      puts "#{rotulos_campos[campo]}: atualizar=#{atualizacoes_do_campo} já_correto=#{corretos_do_campo} divergência=#{divergencias_do_campo} conflito_NF_mais_recente=#{conflitos_nf_mais_recente} divergência_com_vínculo_ambíguo=#{divergencias_ambiguas_do_campo} fonte_ausente_ou_inválida=#{sem_fonte_do_campo}"
    end
    puts "\nDivergências históricas por campo (ocorrências resolvidas; categorias podem se sobrepor):"
    campos.each do |campo|
      historicos = produtos.values.filter_map do |item|
        historico = item[:conflitos_historicos][campo]
        historico if item[:ocorrencias].any? && historico
      end
      puts "#{rotulos_campos[campo]}: produtos=#{historicos.size} apenas_uma_alteracao_antiga=#{historicos.count { |item| item[:uma_alteracao_antiga] }} mais_de_uma_alteracao=#{historicos.count { |item| item[:mais_de_uma_alteracao_antiga] }} conflito_na_data_mais_recente=#{historicos.count { |item| item[:conflito_valores_data_mais_recente] }}"
    end
    puts "Não encontrados=#{relatorio[:nao_encontrados].size} vínculos ambíguos=#{relatorio[:vinculos_ambiguos].size}"
    puts "Produtos com campos marcados para atualização=#{produtos_auditaveis.sum { |item| item[:campos].count { |_nome, detalhe| %i[atualizar atualizado].include?(detalhe[:acao]) } }}"
    puts "Aplicação: #{relatorio[:erro_transacao].present? ? "ROLLBACK: #{relatorio[:erro_transacao]}" : (apply ? "concluída" : "DRY-RUN; nada gravado") }"

    detalhes = produtos.select do |_codigo, item|
      item[:elegivel] || item[:status] == :divergencia_cadastro || item[:conflitos_historicos].any? ||
        (item[:vinculos_ambiguos].any? && item[:campos].values.any? { |campo| campo[:acao] == :divergencia_cadastro })
    end
    puts "\nDetalhamento fiscal de produtos para revisão (#{detalhes.size} produtos):"
    detalhes.each do |cod_produto, item|
      produto = item[:produto]
      acao_produto = if item[:vinculos_ambiguos].any?
        "#{item[:acao]} / VÍNCULO AMBÍGUO; NÃO ATUALIZAR"
      else
        item[:acao]
      end
      rotulo_fonte = item[:vinculos_ambiguos].any? ? "Fonte inequívoca mais recente" : "Fonte mais recente"
      rotulo_nf = item[:vinculos_ambiguos].any? ? "NF mais recente inequívoca" : "NF mais recente"
      puts "Produto cod_produto=#{cod_produto} | nome=#{produto.nome} | ação=#{acao_produto}"
      puts "#{rotulo_fonte}: #{fonte_legivel.call(item[:referencia])}"
      puts "Cadastro atual: origem=#{formatar.call(produto.origem)} | NCM=#{formatar.call(produto.ncm)} | CEST=#{formatar.call(produto.cest)} | GTIN=#{formatar.call(produto.gtin)} | UCOM=#{formatar.call(produto.ucom)} | CFOP=#{formatar.call(produto.cfop)}"
      puts "Valores #{rotulo_nf}: origem=#{formatar.call(item[:campos][:origem][:sugerido])} | NCM=#{formatar.call(item[:campos][:ncm][:sugerido])} | CEST=#{formatar.call(item[:campos][:cest][:sugerido])} | GTIN=#{formatar.call(item[:campos][:gtin][:sugerido])} | UCOM=#{formatar.call(item[:campos][:ucom][:sugerido])} | CFOP=#{formatar.call(item[:cfop_xml])}"
      item[:campos].each do |campo, detalhe|
        acao = rotulos_acoes[detalhe[:acao]] || detalhe[:acao].to_s.upcase
        fonte = detalhe[:fonte]
        valor_xml = detalhe[:sugerido] || (detalhe[:valor_xml].presence && "inválido: #{detalhe[:valor_xml]}") || "(ausente)"
        puts "  #{rotulos_campos[campo]}: atual=#{formatar.call(detalhe[:atual])} | #{rotulo_nf}=#{valor_xml} | ação=#{acao} | validação=#{detalhe[:validacao]} | fonte=#{fonte_legivel.call(fonte)}"
      end
      puts "  CFOP: cadastro=#{formatar.call(item[:cfop_atual])} | NF entrada mais recente=#{formatar.call(item[:cfop_xml])} | INFORMATIVO — NÃO ALTERAR"
      item[:conflitos_historicos].each do |campo, historico|
        referencia = historico[:fonte]
        valores_anteriores = historico[:valores].keys.reject { |valor| valor == historico[:referencia] }
        if historico[:referencia].present? && valores_anteriores.any?
          puts "  Conflito histórico: #{rotulos_campos[campo]}=#{historico[:referencia]} na NF mais recente; #{valores_anteriores.join(", ")} encontrados em NFs anteriores."
        elsif historico[:referencia].blank?
          puts "  Conflito histórico: #{rotulos_campos[campo]} ausente/inválido na NF mais recente; valores #{historico[:valores].keys.join(", ")} encontrados em NFs anteriores."
        end
        puts "    Referência principal: #{fonte_legivel.call(referencia)}"
        historico[:ocorrencias].each do |valor, ocorrencias|
          ocorrencias.each do |ocorrencia|
            posicao = ocorrencia.equal?(referencia) ? "NF mais recente" : "NF anterior"
            puts "    valor=#{valor} | posição=#{posicao} | #{fonte_legivel.call(ocorrencia)}"
          end
        end
      end
    end

    puts "\nDetalhamento de vínculos ambíguos (#{relatorio[:vinculos_ambiguos].size} grupos):"
    relatorio[:vinculos_ambiguos].each_value do |item|
      item[:ocorrencias].each do |ocorrencia|
        puts "Ambíguo | cProd=#{ocorrencia[:cprod]} | GTIN=#{ocorrencia[:gtin]} | nome_xml=#{ocorrencia[:nome_xml]} | fornecedor=#{ocorrencia[:fornecedor]} | NCM=#{ocorrencia[:ncm]} | CEST=#{ocorrencia[:cest]} | candidatos=#{ocorrencia[:codigos_produto_candidatos].join(",")} | motivo=#{ocorrencia[:motivo_vinculo_ambiguo]}"
      end
    end

    puts "\nDetalhamento de não encontrados (#{relatorio[:nao_encontrados].size} grupos):"
    relatorio[:nao_encontrados].each_value do |item|
      item[:ocorrencias].each do |ocorrencia|
        puts "Não encontrado | cProd=#{ocorrencia[:cprod]} | GTIN=#{ocorrencia[:gtin]} | nome_xml=#{ocorrencia[:nome_xml]} | fornecedor=#{ocorrencia[:fornecedor]} | NCM=#{ocorrencia[:ncm]} | CEST=#{ocorrencia[:cest]} | NF=#{ocorrencia[:chave_nf]} | nItem=#{ocorrencia[:nitem]} | motivo=#{ocorrencia[:motivo_nao_encontrado] || item[:motivo] || "sem motivo registrado"}"
      end
    end

    (relatorio[:falhas_xml] || []).each do |falha|
      puts "XML inválido | arquivo=#{falha[:arquivo]} | motivo=#{falha[:motivo]}"
    end
    relatorio[:falhas_gravacao].each do |falha|
      puts "Falha ao gravar | cod_produto=#{falha[:cod_produto]} | motivo=#{falha[:motivo]}"
    end

    caminho_csv = ENV["REPORT_PATH"].presence || Rails.root.join("tmp", "auditoria_origem_nfe_#{Time.current.strftime("%Y%m%d_%H%M%S")}.csv").to_s
    caminho_csv = Fiscal::OrigemProdutoNfeCsvReport.new(relatorio).write(path: caminho_csv)
    puts "Arquivo CSV para revisão: #{caminho_csv}"

    puts(apply ? "Execução concluída." : "DRY-RUN: nenhum dado foi gravado. Use APPLY=1 para aplicar.")
  end
end