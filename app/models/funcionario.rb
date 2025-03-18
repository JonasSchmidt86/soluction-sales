class Funcionario < ApplicationRecord

    self.table_name = "funcionario"
    self.primary_key = "cod_funcionario"
    alias_attribute :id, :cod_funcionario

    has_one_attached :avatar, service: :local_custom
    
    #ativo = true

    belongs_to :pessoa, :class_name => 'Pessoa', :foreign_key => 'cod_pessoa', inverse_of: :funcionario

    belongs_to :permissao, :class_name => 'Permissao', :foreign_key => 'cod_permissao', optional: true

    # verificar para fazer só com Funcionario caixa ligacao
    has_many :funcionario_aberturas, :class_name => 'Caixa', :foreign_key => 'cod_funcionarioabertura', inverse_of: :funcionario_abertura
    has_many :funcionario_fechamentos, :class_name => 'Caixa', :foreign_key => 'cod_funcionariofechamento', inverse_of: :funcionario_fechamento
    
    has_many :compras, :class_name => 'Compra', :foreign_key => 'cod_compra', inverse_of: :collaborator
    
    has_many :vendas, :class_name => 'Venda', :foreign_key => 'cod_funcionario', inverse_of: :funcionario
        
    has_many :lancamentos, :class_name => 'LancamentosCaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :funcionario

    has_one :collaborator, :class_name => 'Collaborator', :foreign_key => 'id'

    accepts_nested_attributes_for :collaborator, reject_if: :all_blank, allow_destroy: true #cocoon gem
    
    has_many :funcionarioempresas, foreign_key: 'cod_funcionario', inverse_of: :funcionario, autosave: true
    has_many :empresas, through: :funcionarioempresas
    
    accepts_nested_attributes_for :funcionarioempresas, reject_if: :all_blank, allow_destroy: true #cocoon gem

    def pessoa_nome
      if !pessoa.blank?
        pessoa.nome
      end
    end

    paginates_per 30

end
