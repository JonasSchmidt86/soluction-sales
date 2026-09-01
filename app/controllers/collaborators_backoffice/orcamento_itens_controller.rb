# frozen_string_literal: true

class CollaboratorsBackoffice::OrcamentoItensController < CollaboratorsBackofficeController
  before_action :set_orcamento
  before_action :set_item, only: [:update, :destroy, :toggle_posicao_foto, :trocar_tamanho_foto, :remover_foto]

  # POST /collaborators_backoffice/orcamentos/:orcamento_id/itens
  def create
    posicao = (@orcamento.itens_orcamentos.maximum(:posicao_ordem) || -1) + 1
    @item = @orcamento.itens_orcamentos.build(
      cod_empresa:   current_collaborator.cod_empresa,
      cod_produto:   nil,
      cod_cor:       nil,
      quantidade:    1,
      valorunitario: 0,
      posicao_ordem: posicao
    )

    if @item.save
      @renderer = OrcamentoRendererService.new(@orcamento.reload)
      render json: {
        success: true,
        item_html: render_to_string(
          partial: "collaborators_backoffice/orcamento_editor/item_card",
          locals: { item: @item, orcamento: @orcamento, tema: @renderer.tema },
          formats: [:html]
        ),
        totais_html: render_to_string(
          partial: "collaborators_backoffice/orcamento_editor/totais",
          locals: { orcamento: @orcamento },
          formats: [:html]
        ),
        item_id: @item.cod_item
      }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/itens/:id
  def update
    # Upload de foto do computador — cria/substitui ItemOrcamentoFoto com origem: upload
    if params.dig(:item, :foto).present?
      foto = _foto_principal_ou_nova
      foto.origem = "upload"
      foto.biblioteca_foto_url = nil
      foto.foto = params[:item][:foto]
      foto.save!(validate: false)
      return render_item_json
    end

    # Foto da biblioteca — cria/substitui ItemOrcamentoFoto com origem: biblioteca
    if params[:produto_imagem_id].present?
      imagem = ProdutoImagem.find(params[:produto_imagem_id])
      if imagem.imagem.attached?
        url = Rails.application.routes.url_helpers.rails_blob_path(imagem.imagem, only_path: true)
        foto = _foto_principal_ou_nova
        foto.remove_foto = true if foto.foto.present?
        foto.origem = "biblioteca"
        foto.biblioteca_foto_url = url
        foto.save!(validate: false)

        # Preencher nome e descrição do produto se ainda estiverem vazios
        produto = imagem.produto
        updates = {}
        updates[:nome_produto_livre] = produto.titulo.presence || produto.nome if @item.nome_produto_livre.blank?
        updates[:descricao_item]     = produto.descricao if @item.descricao_item.blank? && produto.descricao.present?
        @item.update_columns(updates) if updates.any?
      end
      return render_item_json
    end

    if @item.update(item_params)
      @orcamento.recalcular_total!
      render_item_json
    else
      render json: { success: false, errors: @item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /collaborators_backoffice/orcamentos/:orcamento_id/itens/:id
  def destroy
    @item.destroy!
    @orcamento.recalcular_total!
    render json: {
      success: true,
      totais_html: render_to_string(
        partial: "collaborators_backoffice/orcamento_editor/totais",
        locals: { orcamento: @orcamento },
        formats: [:html]
      )
    }
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/itens/:id/toggle_posicao_foto
  def toggle_posicao_foto
    foto = @item.foto_principal
    return render_item_json unless foto

    nova = foto.posicao_foto == "left" ? "right" : "left"
    foto.update!(posicao_foto: nova)
    render_item_json
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/itens/:id/trocar_tamanho_foto
  def trocar_tamanho_foto
    foto = @item.foto_principal
    return render_item_json unless foto

    proximo = { "small" => "medium", "medium" => "large", "large" => "small" }[foto.tamanho_foto]
    foto.update!(tamanho_foto: proximo)
    render_item_json
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/itens/:id/remover_foto
  def remover_foto
    @item.fotos.destroy_all
    render_item_json
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/itens/reordenar
  def reordenar
    (params[:posicoes] || []).each_with_index do |item_id, idx|
      @orcamento.itens_orcamentos.where(cod_item: item_id).update_all(posicao_ordem: idx)
    end
    head :ok
  end

  private

  def set_orcamento
    @orcamento = Orcamento.find(params[:orcamento_id])
  end

  def set_item
    @item = @orcamento.itens_orcamentos.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:cod_produto, :cod_cor, :nome_produto_livre, :descricao_item, :valorunitario, :quantidade)
  end

  def _foto_principal_ou_nova
    @item.foto_principal || @item.fotos.build(posicao_ordem: 0)
  end

  def render_item_json
    @orcamento.reload
    @renderer = OrcamentoRendererService.new(@orcamento)
    render json: {
      success: true,
      item_html: render_to_string(
        partial: "collaborators_backoffice/orcamento_editor/item_card",
        locals: { item: @item.reload, orcamento: @orcamento, tema: @renderer.tema },
        formats: [:html]
      ),
      totais_html: render_to_string(
        partial: "collaborators_backoffice/orcamento_editor/totais",
        locals: { orcamento: @orcamento },
        formats: [:html]
      )
    }
  end
end
