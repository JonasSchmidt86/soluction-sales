# Rateia o estoque fiscal CONSOLIDADO (fiscal_produto.qtd_fiscal) entre as cores
# de empresaproduto, proporcional ao ESTOQUE FISICO (quantidade) de cada cor.
#
# Motivo: o empresaproduto.qtdfiscal so crescia (entradas de compra com NF, sem
# saidas), ficando inflado e divergente do inventario real (fiscal_produto).
# Este rateio reescreve empresaproduto.qtdfiscal para que a SOMA por produto
# bata com fiscal_produto.qtd_fiscal, distribuindo conforme onde o produto
# realmente esta (estoque fisico).
#
# Regras:
#  - fiscal_produto.qtd_fiscal e a FONTE DA VERDADE (NAO e alterado).
#  - Rateio em NUMEROS INTEIROS: cada cor recebe floor(total*fisico/soma_fisico);
#    a sobra (p/ fechar o total exato) vai para a cor de MAIOR fisico.
#  - Se o produto tem fisico 0 em todas as cores: joga tudo na cor 1 (ou na
#    unica cor existente, se houver so uma).
#  - NAO altera empresaproduto.quantidade (estoque fisico).
#  - Loga cada ajuste em estoque_logs (origem EMPRESA_PRODUTO, operacao RATEIO_FISC).
#
# Seguro: DRY-RUN por padrao; grava so com APPLY=1. EMPRESA=n obrigatorio.
#
# Uso:
#   EMPRESA=2 rails fiscal:ratear_qtdfiscal            # dry-run (mostra)
#   APPLY=1 EMPRESA=2 rails fiscal:ratear_qtdfiscal    # aplica
namespace :fiscal do
  desc "Rateia fiscal_produto.qtd_fiscal entre as cores de empresaproduto por estoque fisico (DRY-RUN; APPLY=1 grava; EMPRESA=n)"
  task ratear_qtdfiscal: :environment do
    apply   = ENV["APPLY"] == "1"
    empresa = ENV["EMPRESA"].presence&.to_i
    abort("Informe EMPRESA=n") unless empresa

    fiscais = FiscalProduto.where(cod_empresa: empresa).where("qtd_fiscal > 0")
    total_produtos = fiscais.count
    ajustados = 0
    cores_tocadas = 0
    func = nil # task roda sem usuario logado

    puts "=" * 72
    puts "Rateio qtdfiscal por fisico | empresa=#{empresa} | modo=#{apply ? 'APPLY' : 'DRY-RUN'}"
    puts "fiscal_produto com saldo > 0: #{total_produtos}"
    puts "=" * 72

    fiscais.find_each do |fp|
      total = fp.qtd_fiscal.to_d.to_i
      next if total <= 0

      cores = Empresaproduto.where(cod_empresa: empresa, cod_produto: fp.cod_produto).to_a
      next if cores.empty?

      alvo = ratear(total, cores)        # Hash cod_cor => qtd inteira
      next if alvo.nil?

      # Cores que mudam de valor.
      mudancas = cores.filter_map do |ep|
        novo = alvo[ep.cod_cor].to_i
        atual = ep.qtdfiscal.to_d.to_i
        [ep, atual, novo] if atual != novo
      end
      next if mudancas.empty?

      ajustados += 1
      cores_tocadas += mudancas.size

      if ajustados <= 15 || !apply
        detalhe = mudancas.map { |ep, a, n| "cor#{ep.cod_cor}:#{a}->#{n}" }.join(" ")
        puts "produto #{fp.cod_produto} (total #{total}): #{detalhe}"
      end

      next unless apply

      ActiveRecord::Base.transaction do
        mudancas.each do |ep, atual, novo|
          ep.update_column(:qtdfiscal, novo)
          EstoqueLog.create!(
            cod_empresa: empresa, cod_produto: ep.cod_produto, cod_cor: ep.cod_cor,
            operacao: "RATEIO_FISC", origem: "EMPRESA_PRODUTO",
            qtdfiscal_antes: atual, qtdfiscal_movida: (novo - atual), qtdfiscal_depois: novo,
            cod_funcionario: func, origem_sistema: "RAKE",
            observacao: "Rateio do estoque fiscal por estoque fisico (equiparar fiscal_produto)."
          )
        end
      end
    end

    puts "-" * 72
    puts "Produtos ajustados: #{ajustados} | cores alteradas: #{cores_tocadas}"
    puts(apply ? "APLICADO." : "DRY-RUN: nada gravado. Rode com APPLY=1.")
  end

  # Distribui `total` (inteiro) entre as cores, proporcional ao estoque fisico
  # (quantidade). Retorna Hash cod_cor => qtd inteira (soma == total).
  def ratear(total, cores)
    # Fisico negativo (estoque furado) conta como 0 no peso do rateio — nao
    # existe "proporcao negativa". Assim a cor furada nao rouba saldo das outras.
    fisicos = cores.map { |ep| [ep.cod_cor, [ep.quantidade.to_d, 0].max] }
    soma_fisico = fisicos.sum { |_, q| q }

    if soma_fisico <= 0
      # Sem fisico: tudo na cor 1 se existir, senao na unica/ primeira cor.
      destino = cores.find { |ep| ep.cod_cor == 1 } || cores.min_by(&:cod_cor)
      return nil if destino.nil?
      base = cores.each_with_object({}) { |ep, h| h[ep.cod_cor] = 0 }
      base[destino.cod_cor] = total
      return base
    end

    # Floor proporcional + distribui a sobra para a(s) cor(es) de maior fisico.
    alvo = {}
    acumulado = 0
    fisicos.each do |cor, q|
      v = (total * q / soma_fisico).floor
      alvo[cor] = v
      acumulado += v
    end
    sobra = total - acumulado
    # Ordena por fisico desc; adiciona 1 em cada ate zerar a sobra.
    ordem = fisicos.sort_by { |_, q| -q }.map(&:first)
    i = 0
    while sobra > 0 && ordem.any?
      alvo[ordem[i % ordem.size]] += 1
      sobra -= 1
      i += 1
    end
    alvo
  end
end
