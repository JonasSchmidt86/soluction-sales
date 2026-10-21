module Fiscal
  # Controla o ESTOQUE FISCAL (empresaproduto.qtdfiscal) na emissão/cancelamento
  # de NF — função que ANTES era da trigger de venda e agora é do Rails.
  #
  # Regra: só mexe em itens cuja regra fiscal tem controla_estoque == "proprio".
  # Itens com "nao_controla" (ex: serviço, remessa que não movimenta) são ignorados.
  #
  # NÃO toca no estoque FÍSICO (quantidade) — isso continua na trigger de venda.
  # A ENTRADA de qtdfiscal (compra) continua na trigger de compra; aqui é só SAÍDA.
  #
  # Itens: lista de Hashes neutros, cada um com:
  #   cod_produto:, cod_cor:, quantidade:, controla_estoque: ("proprio"/"nao_controla")
  #
  # Uso:
  #   Fiscal::EstoqueFiscalService.new(
  #     cod_empresa: 2, itens: itens, cod_referencia: doc.cod_documento_fiscal,
  #     cod_funcionario: 1, observacao: "Emissao NF-e 55"
  #   ).baixar!
  class EstoqueFiscalService
    def initialize(cod_empresa:, itens:, cod_referencia: nil, cod_funcionario: nil, observacao: nil)
      @cod_empresa     = cod_empresa
      @itens           = Array(itens)
      @cod_referencia  = cod_referencia
      @cod_funcionario = cod_funcionario
      @observacao      = observacao
    end

    # Emissão: subtrai qtdfiscal dos itens que controlam estoque.
    def baixar!
      aplicar(sinal: -1, operacao: "SAIDA_FISCAL", obs_default: "Emissao NF - baixa estoque fiscal")
    end

    # Cancelamento: devolve qtdfiscal dos itens que controlam estoque.
    def estornar!
      aplicar(sinal: +1, operacao: "ESTORNO_FISCAL", obs_default: "Cancelamento NF - estorno estoque fiscal")
    end

    private

    def aplicar(sinal:, operacao:, obs_default:)
      ActiveRecord::Base.transaction do
        # Acumula o delta consolidado por PRODUTO (soma todas as cores do item)
        # para espelhar em fiscal_produto.qtd_fiscal — o controlador fiscal real
        # de estoque de notas (mesma logica da trigger de compra, por produto).
        delta_por_produto = Hash.new { |h, k| h[k] = BigDecimal("0") }

        @itens.each do |item|
          next unless controla?(item)
          qtd = item[:quantidade].to_d
          next if qtd.zero?

          ep = Empresaproduto.find_by(
            cod_empresa: @cod_empresa,
            cod_produto: item[:cod_produto],
            cod_cor:     item[:cod_cor]
          )
          next if ep.nil? # sem registro de estoque: nada a mexer

          antes  = ep.qtdfiscal.to_d
          movida = sinal * qtd
          depois = antes + movida
          ep.update_column(:qtdfiscal, depois)

          # Consolidado por produto (sem cor): acumula o mesmo delta aplicado
          # na cor. Entrada (compra) faz isso na trigger; saida (venda) aqui.
          delta_por_produto[item[:cod_produto]] += movida

          registrar_log(item, antes, movida, depois, operacao, obs_default)
        end

        aplicar_consolidado_fiscal_produto(delta_por_produto, operacao, obs_default)
      end
    end

    # Atualiza fiscal_produto.qtd_fiscal (consolidado por produto). Upsert: cria
    # o registro com o delta se nao existir; senao soma. Espelha a trigger de
    # compra (tgrf_qtdfiscal_produto), que faz o mesmo na ENTRADA. Grava 1 log
    # consolidado (cod_cor nil) por produto movimentado.
    def aplicar_consolidado_fiscal_produto(delta_por_produto, operacao, obs_default)
      delta_por_produto.each do |cod_produto, delta|
        next if delta.zero?

        registro = FiscalProduto.find_or_initialize_by(
          cod_empresa: @cod_empresa,
          cod_produto: cod_produto
        )
        antes = registro.qtd_fiscal.to_d
        depois = antes + delta
        registro.qtd_fiscal = depois
        registro.ativo = true if registro.ativo.nil?
        registro.save!(validate: false)

        registrar_log_consolidado(cod_produto, antes, delta, depois, operacao, obs_default)
      end
    end

    def controla?(item)
      item[:controla_estoque].to_s == "proprio"
    end

    def registrar_log(item, antes, movida, depois, operacao, obs)
      EstoqueLog.create!(
        cod_empresa:       @cod_empresa,
        cod_produto:       item[:cod_produto],
        cod_cor:           item[:cod_cor],
        operacao:          operacao,
        # origem = TABELA afetada (empresaproduto.qtdfiscal, por cor). A operacao
        # (SAIDA_FISCAL/ESTORNO_FISCAL) diz o que aconteceu.
        origem:            "EMPRESA_PRODUTO",
        # Este serviço mexe SOMENTE no estoque fiscal (qtdfiscal); as colunas
        # físicas (quantidade_*) ficam nil porque o estoque físico é gravado
        # pela trigger de venda, em outro momento (linha separada no log).
        quantidade_antes:  nil,
        quantidade_movida: nil,
        quantidade_depois: nil,
        qtdfiscal_antes:   antes,
        qtdfiscal_movida:  movida,
        qtdfiscal_depois:  depois,
        cod_referencia:    @cod_referencia,
        cod_funcionario:   @cod_funcionario,
        usuario:           nil,
        origem_sistema:    "WEB",
        observacao:        (@observacao.presence || obs).to_s[0, 255]
      )
    rescue => e
      # Log de auditoria não deve derrubar a baixa fiscal; apenas registra.
      Rails.logger.error("[EstoqueFiscalService] falha ao gravar estoque_logs: #{e.class} - #{e.message}")
    end

    # Log do CONSOLIDADO fiscal_produto.qtd_fiscal (por produto, cod_cor nil,
    # origem "FISCAL_PRODUTO" = a tabela afetada). Mesma origem usada pela
    # trigger de compra; entrada e saida no historico da mesma tabela.
    def registrar_log_consolidado(cod_produto, antes, movida, depois, operacao, obs)
      EstoqueLog.create!(
        cod_empresa:       @cod_empresa,
        cod_produto:       cod_produto,
        cod_cor:           nil,              # consolidado: sem cor
        operacao:          operacao,         # SAIDA_FISCAL / ESTORNO_FISCAL
        origem:            "FISCAL_PRODUTO", # tabela afetada (consolidado)
        quantidade_antes:  nil,
        quantidade_movida: nil,
        quantidade_depois: nil,
        qtdfiscal_antes:   antes,
        qtdfiscal_movida:  movida,
        qtdfiscal_depois:  depois,
        cod_referencia:    @cod_referencia,
        cod_funcionario:   @cod_funcionario,
        usuario:           nil,
        origem_sistema:    "WEB",
        observacao:        (@observacao.presence || obs).to_s[0, 255]
      )
    rescue => e
      Rails.logger.error("[EstoqueFiscalService] falha ao gravar log consolidado: #{e.class} - #{e.message}")
    end
  end
end
