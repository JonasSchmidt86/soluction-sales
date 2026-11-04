# Download PUBLICO (sem login) do DANFE/XML de uma NF-e autorizada, aberto pelo
# cliente a partir do link enviado por WhatsApp. O acesso e controlado por um
# token assinado com validade (DocumentoFiscal#token_publico) — sem token valido
# nada e entregue. Nota cancelada nao entrega o arquivo.
class NotasPublicasController < ApplicationController
  layout false

  before_action :set_documento
  before_action :nao_indexar

  # GET /nota/:token — abre o DANFE (PDF) no navegador.
  def danfe
    pdf = Fiscal::ArquivosNota.new(@documento).danfe_pdf
    return indisponivel if pdf.nil?

    send_data pdf, filename: "danfe-#{nome_arquivo}.pdf", type: "application/pdf", disposition: "inline"
  end

  # GET /nota/:token/xml — baixa o XML da NF-e.
  def xml
    conteudo = Fiscal::ArquivosNota.new(@documento).xml
    return indisponivel if conteudo.nil?

    send_data conteudo, filename: "nfe-#{nome_arquivo}.xml", type: "application/xml", disposition: "attachment"
  end

  private

  def set_documento
    @documento = DocumentoFiscal.por_token_publico(params[:token])

    # Mesma resposta para token invalido/expirado e para documento que nao e
    # NF-e autorizada: nao revela se o documento existe.
    if @documento.nil? || !@documento.nfe?
      return render plain: "Link inválido ou expirado.", status: :not_found
    end

    if @documento.cancelada?
      return render plain: "Esta nota fiscal foi cancelada.", status: :gone
    end

    render plain: "Link inválido ou expirado.", status: :not_found unless @documento.autorizada?
  end

  def nao_indexar
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Cache-Control"] = "private, no-store"
  end

  def indisponivel
    render plain: "Arquivo indisponível no momento. Tente novamente mais tarde.", status: :service_unavailable
  end

  def nome_arquivo
    @documento.chave_acesso.presence || @documento.cod_documento_fiscal
  end
end
