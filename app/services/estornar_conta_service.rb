class EstornarContaService
  def initialize(conta, current_user, caixa_atual)
    @conta = conta
    @user = current_user
    @vl_estorno = 0
    @caixa = caixa_atual
  end

    def call
        puts "Iniciando estorno..."

        return @conta unless @conta.ativo?

        ActiveRecord::Base.transaction do
            @conta.update!(ativo: false)

            processar_lancamentos
            criar_estorno if @vl_estorno > 0
        end

        @conta

        rescue => e
            puts "ERRO NO ESTORNO: #{e.message}"
            puts e.backtrace.first(5)
        raise e
    end

  private

  def processar_lancamentos
    return if @conta.lancamentos.blank?
puts "Processando lançamentos para conta COD: #{@conta.cod_contaspagrec}\n"
    @conta.lancamentos.each do |l|
      next if l.cancelada?

      if @conta.venda.present?
        if l.cod_tphitorico == 1
          @vl_estorno += l.valor
        end
        l.update!(cod_tphitorico: 5)

      elsif @conta.compra.present?
        if l.cod_tphitorico == 2
          @vl_estorno += l.valor
        end
        l.update!(cod_tphitorico: 3)

      elsif @conta.frete.present?
        if l.cod_tphitorico == 6
          @vl_estorno += l.valor
        end
        l.update!(cod_tphitorico: 20)
      end
    end
  end

  def criar_estorno
    if @conta.venda.present?
      Lancamentoscaixa.create!(
        caixa: @caixa,
        dataabertura: @caixa.dataabertura,
        cod_empresa: @conta.cod_empresa,
        datapagto: Time.current,
        cod_funcionario: @user.cod_funcionario,
        valor: @vl_estorno,
        tipo: 'S',
        contaspagrec: @conta,
        cod_tphitorico: 4,
        cancelada: false
      )
    else
      Lancamentoscaixa.create!(
        caixa: @caixa,
        dataabertura: @caixa.dataabertura,
        cod_empresa: @conta.cod_empresa,
        datapagto: Time.current,
        cod_funcionario: @user.cod_funcionario,
        valor: @vl_estorno,
        tipo: 'E',
        contaspagrec: @conta,
        cod_tphitorico: 3,
        cancelada: false
      )
    end
  end
end