class TransferenciaService
  def initialize(venda)
    @venda = venda
    @empresa = venda.empresa
    @empresa_destino = Empresa.find(venda.cod_empresa_transferida) # 🔥 você precisa ter isso
    @user = venda.funcionario
  end

  def call
    ActiveRecord::Base.transaction do
        if @venda.transferencia? && @venda.contas.empty?
            conta = criar_conta
            criar_entrada(conta)
            criar_saida(conta)
        end
    end
  end

  private

  def criar_conta
    Contaspagrec.create!(
      ativo: true,
      quitada: true,
      valorparcela: @venda.valortotal,
      numeroparcela: 1,
      cod_empresa: @empresa.cod_empresa,
      dtvencimento: Date.current,
      cod_venda: @venda.cod_venda
    )
  end

  def criar_entrada(conta)
    Lancamentoscaixa.create!(
      cod_empresa: @empresa.cod_empresa,
      cod_funcionario: @user.cod_funcionario,
      datapagto: Time.current,
      tipo: 'E',
      cod_tphitorico: 18,
      cod_contaspagrec: conta.cod_contaspagrec,
      valor: conta.valorparcela,
      cod_bancoconta: @empresa.cod_bancoconta
    )
  end

  def criar_saida(conta)
    Lancamentoscaixa.create!(
      cod_empresa: @empresa_destino.cod_empresa,
      cod_funcionario: @user.cod_funcionario,
      datapagto: Time.current,
      tipo: 'S',
      cod_tphitorico: 18,
      cod_contaspagrec: conta.cod_contaspagrec,
      valor: conta.valorparcela,
      cod_bancoconta: @empresa_destino.cod_bancoconta
    )
  end
end