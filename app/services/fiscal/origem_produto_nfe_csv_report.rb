require "csv"
require "fileutils"

module Fiscal
  class OrigemProdutoNfeCsvReport
    CAMPOS = OrigemProdutoNfeService::CAMPOS_FISCAIS
    HEADERS = %w[
      tipo_registro campo cod_produto nome_produto acao quantidade_atualizar
      quantidade_ja_correto quantidade_divergencia_cadastro
      quantidade_divergencia_cadastro_vinculo_ambiguo quantidade_conflito_nf_mais_recente
      quantidade_sem_fonte
      quantidade_produtos_com_divergencia_historica data_nf chave_nf numero_nf
      fornecedor cprod nitem valor_atual valor_sugerido
      quantidade_ocorrencias_historicas valores_historicos diferentes_em_nfs_anteriores
      apenas_uma_alteracao_antiga mais_de_uma_alteracao_antiga
      conflito_entre_valores_na_data_mais_recente valores_na_data_mais_recente
      possui_vinculo_ambiguo cfop_cadastro cfop_nf
    ].freeze

    def initialize(relatorio)
      @relatorio = relatorio
    end

    def write(path:)
      FileUtils.mkdir_p(File.dirname(path))
      CSV.open(path, "wb", encoding: "bom|utf-8", force_quotes: true) do |csv|
        csv << HEADERS
        csv << ["NOTA", nil, nil, nil, "Contagens históricas por produto/campo podem se sobrepor. Produtos com vínculo ambíguo aparecem apenas como alerta histórico e nunca são sugeridos para atualização."]
        escrever_resumos(csv)
        escrever_divergencias_cadastro(csv)
        escrever_divergencias_historicas(csv)
      end
      File.expand_path(path)
    end

    private

    def produtos_auditaveis
      @relatorio[:produtos].values.select do |dados|
        dados[:ocorrencias].any? && dados[:vinculos_ambiguos].empty?
      end
    end

    def escrever_resumos(csv)
      CAMPOS.each do |campo|
        contagens = produtos_auditaveis.each_with_object(Hash.new(0)) do |dados, resultado|
          acao = dados[:campos].dig(campo, :acao)
          case acao
          when :atualizar, :atualizado then resultado[:atualizar] += 1
          when :ja_correto then resultado[:ja_correto] += 1
          when :divergencia_cadastro then resultado[:divergencia_cadastro] += 1
          when :sem_fonte, :fonte_invalida then resultado[:sem_fonte] += 1
          end
        end
        csv << linha_csv(
          tipo_registro: "RESUMO_CAMPO",
          campo: campo,
          quantidade_atualizar: contagens[:atualizar],
          quantidade_ja_correto: contagens[:ja_correto],
          quantidade_divergencia_cadastro: contagens[:divergencia_cadastro],
          quantidade_divergencia_cadastro_vinculo_ambiguo: divergencias_ambiguas_do_campo(campo).size,
          quantidade_conflito_nf_mais_recente: produtos_auditaveis.count do |dados|
            dados[:campos].dig(campo, :acao) == :conflito_nf_mais_recente
          end,
          quantidade_sem_fonte: contagens[:sem_fonte]
        )

        historicos = historicos_do_campo(campo)
        csv << linha_csv(
          tipo_registro: "RESUMO_HISTORICO",
          campo: campo,
          quantidade_produtos_com_divergencia_historica: historicos.size,
          quantidade_ocorrencias_historicas: historicos.sum { |_codigo, _dados, historico| historico[:valores].values.sum },
          quantidade_alteracoes_antigas: historicos.sum { |_codigo, _dados, historico| historico[:quantidade_alteracoes_antigas] },
          apenas_uma_alteracao_antiga: historicos.count { |_codigo, _dados, historico| historico[:uma_alteracao_antiga] },
          mais_de_uma_alteracao_antiga: historicos.count { |_codigo, _dados, historico| historico[:mais_de_uma_alteracao_antiga] },
          conflito_entre_valores_na_data_mais_recente: historicos.count { |_codigo, _dados, historico| historico[:conflito_valores_data_mais_recente] }
        )
      end
      escrever_resumo_historico_total(csv)
    end

    def escrever_divergencias_cadastro(csv)
      @relatorio[:produtos].each_value do |dados|
        next if dados[:ocorrencias].empty?

        dados[:campos].each do |campo, detalhe|
          next unless detalhe[:acao] == :divergencia_cadastro

          fonte = detalhe[:fonte]
          historico = dados[:conflitos_historicos][campo]
          tipo = dados[:vinculos_ambiguos].any? ? "DIVERGENCIA_CADASTRO_COM_VINCULO_AMBIGUO" : "DIVERGENCIA_CADASTRO"
          csv << linha_detalhe(
            tipo: tipo, campo: campo, dados: dados,
            fonte: fonte, atual: detalhe[:atual], sugerido: detalhe[:sugerido], historico: historico
          )
        end
      end
    end

    def escrever_divergencias_historicas(csv)
      historicos_do_campo = CAMPOS.flat_map do |campo|
        historicos_do_campo(campo).map { |codigo, dados, historico| [campo, codigo, dados, historico] }
      end

      historicos_do_campo.each do |campo, _codigo, dados, historico|
        csv << linha_detalhe(
          tipo: "DIVERGENCIA_HISTORICA", campo: campo, dados: dados,
          fonte: historico[:fonte], sugerido: historico[:referencia], historico: historico
        )
      end
    end

    def historicos_do_campo(campo)
      @relatorio[:produtos].values.filter_map do |dados|
        next if dados[:ocorrencias].empty?
        historico = dados[:conflitos_historicos][campo]
        [dados[:produto].cod_produto, dados, historico] if historico
      end
    end

    def divergencias_ambiguas_do_campo(campo)
      @relatorio[:produtos].values.select do |dados|
        dados[:ocorrencias].any? && dados[:vinculos_ambiguos].any? &&
          dados[:campos].dig(campo, :acao) == :divergencia_cadastro
      end
    end

    def escrever_resumo_historico_total(csv)
      historicos = @relatorio[:produtos].values.select do |dados|
        dados[:ocorrencias].any? && dados[:conflitos_historicos].any?
      end
      alteracoes_por_produto = historicos.map do |dados|
        dados[:conflitos_historicos].values.sum { |historico| historico[:quantidade_alteracoes_antigas] }
      end
      csv << linha_csv(
        tipo_registro: "RESUMO_HISTORICO_TOTAL",
        campo: "TODOS",
        quantidade_produtos_com_divergencia_historica: historicos.size,
        quantidade_ocorrencias_historicas: historicos.sum { |dados| dados[:ocorrencias].size },
        quantidade_alteracoes_antigas: alteracoes_por_produto.sum,
        apenas_uma_alteracao_antiga: alteracoes_por_produto.count { |quantidade| quantidade == 1 },
        mais_de_uma_alteracao_antiga: alteracoes_por_produto.count { |quantidade| quantidade > 1 },
        conflito_entre_valores_na_data_mais_recente: historicos.count do |dados|
          dados[:conflitos_historicos].values.any? { |historico| historico[:conflito_valores_data_mais_recente] }
        end
      )
    end

    def linha_detalhe(tipo:, campo:, dados:, fonte:, atual: nil, sugerido: nil, historico: nil)
      produto = dados[:produto]
      valores_historicos = historico ? historico[:valores].map { |valor, quantidade| "#{valor}=#{quantidade}" }.join("; ") : nil
      diferentes_em_nfs_anteriores = historico ? historico[:alteracoes_antigas].map { |item| item.dig(:valores_validos, campo) }.uniq.join("|") : nil
      linha_csv(
        tipo_registro: tipo,
        campo: campo,
        cod_produto: produto.cod_produto,
        nome_produto: produto.nome,
        acao: if tipo == "DIVERGENCIA_CADASTRO_COM_VINCULO_AMBIGUO"
          "DIVERGÊNCIA DE CADASTRO / VÍNCULO AMBÍGUO; NÃO ATUALIZAR"
        elsif tipo == "DIVERGENCIA_CADASTRO"
          "DIVERGÊNCIA DE CADASTRO"
        else
          "CONFLITO HISTÓRICO"
        end,
        data_nf: fonte&.dig(:data_emissao)&.strftime("%Y-%m-%d %H:%M:%S"),
        chave_nf: fonte&.[](:chave_nf),
        numero_nf: fonte&.[](:numero_nf),
        fornecedor: fonte&.[](:fornecedor),
        cprod: fonte&.[](:cprod),
        nitem: fonte&.[](:nitem),
        valor_atual: atual,
        valor_sugerido: sugerido,
        quantidade_ocorrencias_historicas: dados[:ocorrencias].size,
        valores_historicos: valores_historicos,
        diferentes_em_nfs_anteriores: diferentes_em_nfs_anteriores,
        apenas_uma_alteracao_antiga: historico&.[](:uma_alteracao_antiga),
        mais_de_uma_alteracao_antiga: historico&.[](:mais_de_uma_alteracao_antiga),
        conflito_entre_valores_na_data_mais_recente: historico&.[](:conflito_valores_data_mais_recente),
        valores_na_data_mais_recente: historico&.[](:valores_data_mais_recente)&.join("|"),
        possui_vinculo_ambiguo: dados[:vinculos_ambiguos].any?,
        cfop_cadastro: dados[:cfop_atual],
        cfop_nf: fonte&.[](:cfop)
      )
    end

    def linha_csv(valores)
      HEADERS.map { |header| valores[header.to_sym] }
    end
  end
end