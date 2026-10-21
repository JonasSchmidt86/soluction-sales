module Fiscal
  # Classifica as linhas parseadas da planilha de inventario, por empresa, em:
  #   :pronto           -> produto existe e NCM confere (ou planilha sem NCM);
  #                        pode importar direto (vai no lote).
  #   :ncm_divergente   -> produto existe mas o NCM da planilha difere do atual;
  #                        importa atualizando o NCM (opcao B), destacado na tela.
  #   :nao_cadastrado   -> codigo nao existe em produto; precisa cadastro rapido.
  #   :erro             -> erro de parse (quantidade/codigo/NCM invalidos).
  #
  # NAO grava nada — so analisa e devolve uma estrutura para a tela/lote.
  class ClassificadorInventario
    Resultado = Struct.new(
      :linha_planilha, :codigo, :quantidade, :ncm_planilha,
      :nome_planilha, :nome_cadastro, :ncm_atual, :status, :erros,
      :valor_unitario, :valor_venda, :unidade_medida, :codigo_invalido,
      keyword_init: true
    )

    def initialize(cod_empresa:, linhas:)
      @cod_empresa = cod_empresa
      @linhas = Array(linhas)
    end

    def classificar
      codigos = @linhas.filter_map { |l| l[:codigo].to_i if l[:codigo].to_s.match?(/\A\d+\z/) }.uniq
      produtos = Produto.where(cod_produto: codigos).index_by { |p| p.cod_produto.to_s }
      # Fiscal por empresa (fiscal_produto) ja existente, para comparar o NCM atual.
      fiscais = FiscalProduto.where(cod_empresa: @cod_empresa, cod_produto: codigos)
                             .index_by { |f| f.cod_produto.to_s }

      @linhas.map do |l|
        erros = Array(l[:erros])
        prod = produtos[l[:codigo].to_s]
        fiscal = fiscais[l[:codigo].to_s]
        # NCM atual = o da fiscal_produto (se houver) senao o do produto global.
        ncm_atual = (fiscal&.ncm.presence || prod&.ncm).to_s.strip
        ncm_planilha = l[:ncm].to_s.strip

        # "Codigo nao numerico" NAO bloqueia o cadastro: a pessoa pode apagar o
        # codigo (gera auto) ou digitar um valido. Erros de nome/ncm/quantidade
        # SIM bloqueiam (falta dado essencial) -> so Excluir.
        codigo_invalido = erros.include?("Código não numérico")
        erros_bloqueantes = erros - ["Código não numérico"]

        status =
          if erros_bloqueantes.any?
            :erro
          elsif prod.nil?
            # codigo vazio OU com letras (nao casa com produto) -> cadastro editavel
            :nao_cadastrado
          elsif ncm_planilha.present? && ncm_planilha != ncm_atual
            :ncm_divergente
          else
            :pronto
          end

        Resultado.new(
          linha_planilha: l[:linha_planilha],
          codigo: l[:codigo],
          quantidade: l[:quantidade],
          ncm_planilha: ncm_planilha,
          nome_planilha: l[:nome].to_s.strip,
          nome_cadastro: prod&.nome.to_s.strip,
          ncm_atual: ncm_atual,
          status: status,
          erros: erros,
          valor_unitario: l[:valor_unitario],
          valor_venda: l[:valor_venda],
          unidade_medida: l[:unidade_medida],
          codigo_invalido: codigo_invalido
        )
      end
    end
  end
end
