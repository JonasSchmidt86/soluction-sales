class OrcamentosPublicosController < ApplicationController
  layout false

  before_action :set_orcamento
  before_action :validar_expiracao, only: [:show, :pdf]
  before_action :validar_fotos, only: [:show, :pdf]
  before_action :validar_senha, only: [:show], if: -> { @orcamento.link_requer_senha? && (params[:senha].present? || request.post?) }

  def show
    if @orcamento.link_expirado?
      return render 'orcamentos_publicos/acesso', locals: { orcamento: @orcamento, erro: 'Este orçamento expirou e não pode mais ser acessado.' }
    end

    # Link aberto (sem senha): exibe direto.
    # Link protegido: exige senha válida antes de exibir.
    if @orcamento.link_requer_senha? && !(params[:senha].present? && @senha_valida)
      return render 'orcamentos_publicos/acesso', locals: { orcamento: @orcamento }
    end

    OrcamentoAnalyticsService.record_view(@orcamento)
    render template: 'orcamentos_publicos/show', locals: { orcamento: @orcamento }
  end

  def pdf
    if @orcamento.link_expirado?
      return render plain: 'Este orçamento expirou e não pode mais ser acessado.', status: :forbidden
    end

    renderer = OrcamentoRendererService.new(@orcamento)
    html = ApplicationController.render(
      partial: 'collaborators_backoffice/orcamento_renderer/documento',
      layout: false,
      locals: { orcamento: @orcamento, tema: renderer.tema, itens: renderer.itens }
    )

    pdf = WickedPdf.new.pdf_from_string(html, orientation: 'Portrait', page_size: 'A4')
    send_data pdf, filename: "orcamento-#{@orcamento.cod_orcamento}.pdf", type: 'application/pdf', disposition: 'attachment'
  end

  def record_duration
    seconds = params[:seconds].to_i
    return head :ok if seconds <= 0

    OrcamentoAnalyticsService.record_duration(@orcamento, duration_seconds: seconds)
    head :ok
  end

  private

  def set_orcamento
    @orcamento = Orcamento.find_by!(cod_orcamento: params[:id])
  end

  def validar_senha
    senha = params[:senha].to_s.gsub(/\D/, '')
    @senha_valida = @orcamento.senha_publica == senha

    return if @senha_valida

    render 'orcamentos_publicos/acesso', status: :forbidden, locals: { orcamento: @orcamento, erro: 'Senha inválida' }
  end

  def validar_expiracao
    return unless @orcamento.link_expirado?

    render 'orcamentos_publicos/acesso', status: :forbidden, locals: { orcamento: @orcamento, erro: 'Este orçamento expirou e não pode mais ser acessado.' }
  end

  def validar_fotos
    return if @orcamento.tem_fotos?

    render 'orcamentos_publicos/acesso', status: :forbidden, locals: { orcamento: @orcamento, erro: 'Este orçamento ainda não possui fotos para gerar o link público.' }
  end
end
