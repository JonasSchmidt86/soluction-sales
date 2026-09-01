# frozen_string_literal: true

class CollaboratorsBackoffice::OrcamentoEditorController < CollaboratorsBackofficeController
  before_action :set_orcamento

  # GET /collaborators_backoffice/orcamentos/:orcamento_id/editor
  def show
    @renderer = OrcamentoRendererService.new(@orcamento)
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/editor/auto_save
  def auto_save
    if @orcamento.update(auto_save_params)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/editor/trocar_tema
  def trocar_tema
    tema = params[:tema].to_s
    if Orcamento::TEMAS.include?(tema)
      @orcamento.update!(tema: tema)
      @renderer = OrcamentoRendererService.new(@orcamento.reload)
      render partial: "collaborators_backoffice/orcamento_editor/documento_inline",
             locals: { orcamento: @orcamento, renderer: @renderer }
    else
      head :unprocessable_entity
    end
  end

  # PATCH /collaborators_backoffice/orcamentos/:orcamento_id/editor/salvar_link
  # Persiste as opções de compartilhamento: proteção por senha, senha customizada
  # e validade do link (24h/48h/7d/até a validade do orçamento).
  def salvar_link
    @orcamento.link_protegido = ActiveModel::Type::Boolean.new.cast(params[:link_protegido])

    if @orcamento.link_protegido?
      senha = params[:senha_publica_customizada].to_s.gsub(/\D/, '')
      @orcamento.senha_publica_customizada = senha.presence
    else
      # Link aberto: descarta senha customizada.
      @orcamento.senha_publica_customizada = nil
    end

    @orcamento.aplicar_validade_link(params[:validade_link]) if params.key?(:validade_link)

    if @orcamento.save
      render json: {
        link_protegido: @orcamento.link_protegido?,
        senha_efetiva: @orcamento.link_requer_senha? ? @orcamento.senha_publica : nil,
        link_expira_em: @orcamento.link_expira_em&.iso8601
      }
    else
      render json: { erros: @orcamento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_orcamento
    @orcamento = Orcamento.find(params[:orcamento_id])
  end

  def auto_save_params
    params.require(:orcamento).permit(:titulo, :data_validade, :desconto, :observacoes,
                                      :cor_primaria, :cor_secundaria, :cor_destaque)
  end
end
