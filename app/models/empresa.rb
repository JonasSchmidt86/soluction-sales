class Empresa < ApplicationRecord

    self.table_name = "empresa"
    self.primary_key = "cod_empresa"

    has_many :lembretes # um para muitos
    has_many :collaborators # um para muitos

    has_many :funcionariosempresa, :class_name => 'Funcionarioempresa', :foreign_key => 'cod_funcionario'

    has_many :funcionarios, :class_name => 'Funcionario', :through => :funcionariosempresa

    has_many :vendas, :class_name => 'Venda', :foreign_key => 'cod_venda', inverse_of: :empresa
    
    has_many :lancamentos, :class_name => 'LancamentosCaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :empresa

    has_many :fretes, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :empresa

    accepts_nested_attributes_for :funcionariosempresa, reject_if: :all_blank, allow_destroy: false #cocoon gem

end
