class CollaboratorsBackoffice::Vendas::PrintsController < CollaboratorsBackofficeController

  def delivery_receipt
    @venda = Venda.includes(:pessoa, :funcionario, :empresa, itensvenda: [:produto, :cor])
                  .find(params[:cod_venda])
    @parcelas = Contaspagrec
                .where(cod_venda: params[:cod_venda])
                .order(:dtvencimento)

    render layout: 'impressao'
  end

end
