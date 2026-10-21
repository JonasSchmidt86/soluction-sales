module Fiscal
  # Aplica UMA linha de inventario fiscal (produto JA existente) numa empresa:
  #   - empresaproduto.qtdfiscal (cor 1, cria o vinculo se nao existir) = qtd
  #   - fiscal_produto.qtd_fiscal = qtd
  #   - NAO toca empresaproduto.quantidade (estoque fisico real)
  #   - NCM divergente: atualiza fiscal_produto.ncm com o da planilha (opcao B)
  # Registra log em estoque_logs (origem FISCAL_PRODUTO, operacao IMPORT_INVENTARIO)
  # e em produto_fiscal_logs quando o NCM muda.
  #
  # NAO abre transacao propria: o chamador (lote) controla a transacao por linha.
  # Retorna Hash: sucesso { ok: true, saldo: } ou erro { ok: false, erro: }.
  class AplicadorInventario
    COR_PADRAO = 1

    def initialize(cod_empresa:, cod_funcionario:, usuario: nil)
      @cod_empresa = cod_empresa
      @cod_funcionario = cod_funcionario
      @usuario = usuario
    end

    # codigo: cod_produto (numerico, produto ja existe)
    # quantidade: BigDecimal/numeric
    # ncm: NCM a aplicar (opcional; quando presente e diferente, atualiza)
    # valor_unitario: custo (opcional; so preenche ultimocusto se estiver 0/vazio)
    # valor_venda: preco de venda (opcional; so preenche valorvenda se 0/vazio)
    # unidade_medida: ucom (opcional; so preenche produto.ucom se estiver vazio)
    def aplicar!(codigo:, quantidade:, ncm: nil, valor_unitario: nil, valor_venda: nil, unidade_medida: nil)
      produto = Produto.find_by(cod_produto: codigo)
      return { ok: false, erro: "Produto #{codigo} não encontrado." } if produto.nil?

      qtd = quantidade.is_a?(BigDecimal) ? quantidade : BigDecimal(quantidade.to_s)
      return { ok: false, erro: "Quantidade inválida." } if qtd.negative?

      atualizar_ncm_fiscal_produto(produto, ncm)
      atualizar_ucom_produto(produto, unidade_medida)
      gravar_qtd_fiscal_produto(produto, qtd)
      gravar_qtd_empresaproduto(produto, qtd, valor_unitario, valor_venda)

      { ok: true, saldo: qtd.to_s("F") }
    rescue => e
      Rails.logger.error("[AplicadorInventario] produto #{codigo}: #{e.class} - #{e.message}")
      { ok: false, erro: e.message }
    end

    private

    # fiscal_produto.qtd_fiscal (consolidado por produto) = qtd, com log.
    def gravar_qtd_fiscal_produto(produto, qtd)
      registro = FiscalProduto.find_or_initialize_by(
        cod_empresa: @cod_empresa, cod_produto: produto.cod_produto
      )
      antes = registro.qtd_fiscal.to_d
      registro.ativo = true if registro.ativo.nil?
      registro.qtd_fiscal = qtd
      registro.save!(validate: false)

      logar_estoque(produto.cod_produto, cod_cor: nil, antes: antes, depois: qtd)
    end

    # empresaproduto.qtdfiscal da COR 1 (cria o vinculo se nao existir) = qtd.
    # NAO altera empresaproduto.quantidade (estoque fisico).
    # Custo/venda: so preenche quando o valor atual estiver 0/vazio (nao
    # sobrescreve um custo/preco ja definido).
    def gravar_qtd_empresaproduto(produto, qtd, valor_unitario = nil, valor_venda = nil)
      ep = Empresaproduto.find_or_initialize_by(
        cod_empresa: @cod_empresa, cod_produto: produto.cod_produto, cod_cor: COR_PADRAO
      )
      antes = ep.qtdfiscal.to_d
      ep.qtdfiscal = qtd
      ep.quantidade = ep.quantidade || 0 # novo vinculo: fisico zero (nao furar estoque)

      custo = to_decimal(valor_unitario)
      if custo&.positive? && ep.ultimocusto.to_d.zero?
        ep.ultimocusto = custo
      end
      venda = to_decimal(valor_venda)
      if venda&.positive? && ep.valorvenda.to_d.zero?
        ep.valorvenda = venda
      end

      ep.save!(validate: false)
      logar_estoque(produto.cod_produto, cod_cor: COR_PADRAO, antes: antes, depois: qtd)
    end

    def to_decimal(v)
      return nil if v.nil?
      v.is_a?(BigDecimal) ? v : (BigDecimal(v.to_s) rescue nil)
    end

    # Atualiza o NCM na fiscal_produto quando vier um NCM valido e diferente.
    def atualizar_ncm_fiscal_produto(produto, ncm)
      ncm = ncm.to_s.strip
      return unless ncm.match?(/\A\d{8}\z/)

      registro = FiscalProduto.find_or_initialize_by(
        cod_empresa: @cod_empresa, cod_produto: produto.cod_produto
      )
      atual = (registro.ncm.presence || produto.ncm).to_s.strip
      return if atual == ncm

      registro.ativo = true if registro.ativo.nil?
      registro.ncm = ncm
      registro.save!(validate: false)

      ProdutoFiscalLog.create!(
        cod_produto: produto.cod_produto, cod_empresa: @cod_empresa,
        campo: "ncm", valor_antigo: atual.presence, valor_novo: ncm,
        created_at: Time.current
      )
    rescue => e
      Rails.logger.error("[AplicadorInventario] NCM produto #{produto.cod_produto}: #{e.class} - #{e.message}")
    end

    # Unidade de medida (produto.ucom): so preenche quando estiver vazia (nao
    # sobrescreve uma unidade ja cadastrada). ucom tem limite 8.
    def atualizar_ucom_produto(produto, unidade)
      u = unidade.to_s.strip.first(8)
      return if u.blank?
      return if produto.ucom.to_s.strip.present?
      produto.update_columns(ucom: u)
    rescue => e
      Rails.logger.error("[AplicadorInventario] ucom produto #{produto.cod_produto}: #{e.class} - #{e.message}")
    end

    def logar_estoque(cod_produto, cod_cor:, antes:, depois:)
      movida = depois.to_d - antes.to_d
      EstoqueLog.create!(
        cod_empresa: @cod_empresa,
        cod_produto: cod_produto,
        cod_cor: cod_cor,
        operacao: "IMPORT_INV", # <=15 chars (limite da coluna operacao)
        origem: cod_cor.nil? ? "FISCAL_PRODUTO" : "EMPRESA_PRODUTO",
        quantidade_antes: nil, quantidade_movida: nil, quantidade_depois: nil,
        qtdfiscal_antes: antes, qtdfiscal_movida: movida, qtdfiscal_depois: depois,
        cod_funcionario: @cod_funcionario,
        usuario: @usuario.to_s.first(100).presence,
        origem_sistema: "WEB",
        observacao: "Importação de inventário fiscal (saldo definido)."
      )
    rescue => e
      Rails.logger.error("[AplicadorInventario] log estoque produto #{cod_produto}: #{e.class} - #{e.message}")
    end
  end
end
