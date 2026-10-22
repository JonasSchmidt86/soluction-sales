class AddDadosDevolucaoToDocumentoFiscalItem < ActiveRecord::Migration[7.1]
  # Snapshot dos dados fiscais do item de DEVOLUCAO para salvar/reabrir rascunho
  # sem depender de reler o XML da compra. Guarda (jsonb):
  #   - imposto: espelho do XML (icms/ipi/pis/cofins com cst/base/aliquota/valor/
  #     base_st/valor_st);
  #   - imposto_override: edicoes manuais da tela (icms_base/valor/aliquota, ipi_valor/aliquota);
  #   - quantidade_original (fator de rateio), ncm, cfop_original, ean, unidade,
  #     origem, descricao (nome do XML).
  # Os campos basicos (cod_produto, cod_cor, quantidade, valorunitario, cfop,
  # cod_perfil_tributario) continuam nas colunas proprias do documento_fiscal_item.
  def change
    unless column_exists?(:documento_fiscal_item, :dados_devolucao)
      add_column :documento_fiscal_item, :dados_devolucao, :jsonb,
                 comment: "Snapshot fiscal do item de devolucao (imposto espelho + override + dados do XML)"
    end
  end
end
