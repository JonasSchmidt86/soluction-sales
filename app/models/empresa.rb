class Empresa < ApplicationRecord

    self.table_name = "empresa"
    self.primary_key = "cod_empresa"

    has_many :lembretes # um para muitos
    has_many :collaborators # um para muitos

    has_many :funcionarios, :class_name => 'Funcionario', :through => :funcionariosempresa
    has_many :whatsapp_contacts, foreign_key: 'empresa_id', primary_key: 'cod_empresa'
    has_many :vendas, :class_name => 'Venda', :foreign_key => 'cod_venda', inverse_of: :empresa
    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa'
    has_many :lancamentos, :class_name => 'LancamentosCaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :empresa

    has_many :fretes, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :empresa

    #has_many :funcionario_empresas, :class_name => 'Funcionarioempresa', :foreign_key => 'cod_funcionario'
    # employees funcionarios
    #has_many :employees, :through => :funcionario_empresas

    has_many :funcionarioempresas, foreign_key: 'cod_empresa', inverse_of: :empresa
    has_many :employees, through: :funcionarioempresas

    has_many :pedidos_compras, foreign_key: :cod_empresa, primary_key: :cod_empresa

    accepts_nested_attributes_for :employees, reject_if: :all_blank, allow_destroy: false #cocoon gem

    def to_s
        self.nome;
    end

    def horario_comercial?
        return true unless controlar_horario?
        
        agora = Time.current.strftime("%H:%M")
        inicio = horario_comercial_inicio&.strftime("%H:%M")
        fim = horario_comercial_fim&.strftime("%H:%M")
        
        return true if inicio.nil? || fim.nil?
        puts "Horário Comercial: #{inicio} - #{fim}, Agora: #{agora}"
        agora >= inicio && agora <= fim
    end
end
