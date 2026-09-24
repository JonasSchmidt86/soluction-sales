module CollaboratorsBackofficeHelper

    def avatar_url
        avatar = current_collaborator.funcionario.avatar
        avatar.attached? ? avatar : 'img.jpg'
    end

    def get_operacao
        @test = ["Entrada", 2], ["Saida", 3], ["Canceladas", 4]
    end

    # Tabela oficial de Origem da Mercadoria (SEFAZ) usada na NF-e/NFC-e.
    # Chave = codigo que vai no XML (string "0".."8"), valor = descricao.
    ORIGENS_MERCADORIA = {
        "0" => "Nacional (exceto 3, 4, 5 e 8)",
        "1" => "Estrangeira - Importacao direta (exceto 6)",
        "2" => "Estrangeira - Adquirida no mercado interno (exceto 7)",
        "3" => "Nacional - importacao > 40% e <= 70%",
        "4" => "Nacional - processos produtivos basicos",
        "5" => "Nacional - importacao <= 40%",
        "6" => "Estrangeira - Importacao direta, sem similar nacional (CAMEX)",
        "7" => "Estrangeira - Mercado interno, sem similar nacional (CAMEX)",
        "8" => "Nacional - importacao > 70%"
    }.freeze

    # Opcoes prontas para options_for_select: [["0 - Nacional...", "0"], ...]
    def origens_para_select
        ORIGENS_MERCADORIA.map { |cod, desc| ["#{cod} - #{desc}", cod] }
    end

    # Descricao "0 - Nacional..." a partir do codigo. Retorna vazio se nil.
    def origem_descricao(codigo)
        cod = codigo.to_s.strip
        return "" if cod.blank?
        desc = ORIGENS_MERCADORIA[cod]
        desc ? "#{cod} - #{desc}" : cod
    end

    # Tabela de CSOSN (Codigo de Situacao da Operacao no Simples Nacional).
    # Lista fixa oficial usada na NF-e/NFC-e enquanto durar a transicao da
    # reforma tributaria (ICMS convive com IBS/CBS). Chave = codigo, valor = descricao.
    CSOSN_SIMPLES = {
        "101" => "Tributada com permissao de credito",
        "102" => "Tributada sem permissao de credito",
        "103" => "Isencao do ICMS para faixa de receita bruta",
        "201" => "Tributada com permissao de credito e com ST",
        "202" => "Tributada sem permissao de credito e com ST",
        "203" => "Isencao do ICMS com ST",
        "300" => "Imune",
        "400" => "Nao tributada",
        "500" => "ICMS cobrado anteriormente por ST",
        "900" => "Outros"
    }.freeze

    # Opcoes prontas para options_for_select: [["102 - Tributada...", "102"], ...]
    def csosn_para_select
        CSOSN_SIMPLES.map { |cod, desc| ["#{cod} - #{desc}", cod] }
    end

    # Descricao "102 - Tributada..." a partir do codigo. Retorna vazio se nil.
    def csosn_descricao(codigo)
        cod = codigo.to_s.strip
        return "" if cod.blank?
        desc = CSOSN_SIMPLES[cod]
        desc ? "#{cod} - #{desc}" : cod
    end

    def get_cores(id_produto)
        unless id_produto.nil?
            cores = Core.select(:nmcor, :cod_cor).joins(:empresaprodutos).where("cod_produto = ? and cod_empresa = ?", id_produto, current_collaborator.cod_empresa );
            return cores
        end
    end

    def registro_scpc( parametros )
        puts "------------------>>>>ESSE Paramentro ---->> " + parametros.to_s
        if parametros.nil?
            "Não consultado" 
        else
            if parametros.to_s == "false"
                "Sem Registro"
            else
                "Com Registro"
            end
        end
    end

    # Mensagens de WhatsApp ativas da empresa logada (memoizado por request).
    def whatsapp_messages_ativas
        @whatsapp_messages_ativas ||=
            WhatsappMessage.da_empresa(current_collaborator.cod_empresa).ativas.to_a
    end

    # Monta a URL do WhatsApp para um número, com mensagem opcional já renderizada.
    # Ex.: "(45)99996-7722" => "https://wa.me/5545999967722?text=..."
    def whatsapp_link(fone_zap, mensagem = nil)
        digitos = fone_zap.to_s.gsub(/\D/, "")
        return nil if digitos.blank?

        digitos = "55#{digitos}" unless digitos.start_with?("55")

        # Usa api.whatsapp.com/send: repassa o texto (emoji/acentos) para o app
        # de forma mais consistente do que o encurtador wa.me.
        if mensagem.present?
            # Garante UTF-8 antes de escapar para não quebrar emojis/acentos (evita os "�").
            # url_encode faz percent-encoding com %20 no lugar de "+".
            texto = mensagem.to_s
                          .encode("UTF-8", invalid: :replace, undef: :replace)
                          .gsub("\r\n", "\n") # normaliza quebras de linha (evita CR)
            "https://api.whatsapp.com/send?phone=#{digitos}&text=#{ERB::Util.url_encode(texto)}"
        else
            "https://wa.me/#{digitos}"
        end
    end

    # Renderiza o botão/menu de WhatsApp para um cliente.
    #
    # - Sem mensagens cadastradas: link direto que só abre a conversa.
    # - Com mensagens: dropdown com "Só abrir conversa" + uma opção por mensagem
    #   (cada uma com os placeholders {{...}} já substituídos para este cliente).
    #
    # @param fone_zap [String] telefone/celular (com ou sem máscara)
    # @param nome_cliente [String] nome completo do cliente
    # @param css [String] classes extras para o ícone/gatilho
    def whatsapp_client_button(fone_zap, nome_cliente, css: "text-success ms-1")
        base_url = whatsapp_link(fone_zap)
        return "".html_safe if base_url.blank?

        mensagens = whatsapp_messages_ativas
        nome_empresa = current_collaborator.empresa&.nome

        # Sem mensagens cadastradas: abre direto, sem menu.
        if mensagens.empty?
            return link_to(base_url, target: "_blank", class: css, title: "WhatsApp") do
                content_tag(:i, "", class: "fab fa-whatsapp")
            end
        end

        # Com mensagens: menu próprio (não usa o dropdown do Bootstrap).
        # O menu é anexado ao <body> por JS ao abrir e posicionado com position: fixed,
        # o que evita o clipping por contêineres com overflow (widget-scroll /
        # table-responsive) e o problema de abrir fora da tela no último item.
        gatilho = content_tag(:a, href: "#", class: "#{css} text-decoration-none wa-menu-toggle",
                              role: "button", title: "WhatsApp") do
            content_tag(:i, "", class: "fab fa-whatsapp")
        end

        itens = [].tap do |lista|
            lista << link_to("Só abrir conversa", base_url, target: "_blank", class: "wa-menu-item")
            lista << content_tag(:div, "", class: "wa-menu-divider")
            mensagens.each do |msg|
                texto = msg.render(nome_cliente: nome_cliente, nome_empresa: nome_empresa)
                lista << link_to(msg.titulo, whatsapp_link(fone_zap, texto), target: "_blank", class: "wa-menu-item")
            end
        end.join.html_safe

        menu = content_tag(:div, itens, class: "wa-menu", role: "menu")

        content_tag(:span, gatilho + menu, class: "wa-menu-wrap d-inline-block")
    end
end
