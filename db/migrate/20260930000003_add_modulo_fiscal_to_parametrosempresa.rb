class AddModuloFiscalToParametrosempresa < ActiveRecord::Migration[7.1]
  # Liga/desliga o MODULO FISCAL por empresa (definido no cadastro da empresa).
  # Quando true: aparece o menu Fiscal e a tela Configuracao (onde se ativa o
  # FiscalConfig). O restante do fiscal (emissao, dashboard, etc.) continua
  # dependendo de ter o FiscalConfig ATIVO (Empresa#modulo_fiscal?).
  # Default false: empresas sem o modulo nao veem nada fiscal.
  def change
    unless column_exists?(:parametrosempresa, :modulo_fiscal)
      add_column :parametrosempresa, :modulo_fiscal, :boolean, default: false,
                 comment: "Habilita o modulo fiscal (menu + tela de Configuracao) para a empresa"
    end
  end
end
