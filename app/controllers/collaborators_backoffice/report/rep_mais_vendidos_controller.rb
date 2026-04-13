class CollaboratorsBackoffice::Report::RepMaisVendidosController < CollaboratorsBackofficeController

  def index
    return unless params[:dataInicial].present? && params[:dataFinal].present?

    @items = RelatorioProdutosMaisVendidosService.call(
      params,
      current_collaborator.cod_empresa
    )
  end

end
