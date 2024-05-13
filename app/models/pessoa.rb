class Pessoa < ApplicationRecord

    self.table_name = "pessoa"
    self.primary_key = "cod_pessoa"
    
    has_many :vendas, :class_name => 'Venda', :foreign_key => 'cod_pessoa'
    has_many :compras, :class_name => 'Compra', :foreign_key => 'cod_pessoa'
    has_many :funcionario, :class_name => 'Funcionario', :foreign_key => 'cod_pessoa'
    has_many :fretes, :class_name => 'Frete', :foreign_key => 'cod_frete', inverse_of: :pessoa
    
    belongs_to :cidade, class_name: "Cidade", foreign_key: "cod_cidade", inverse_of: :pessoas
    
    # has_one :funcionario, :inverse_of :pessoa
            
    has_many :lancamentos, :class_name => 'Lancamentoscaixa', :foreign_key => 'cod_lancamentocaixa', inverse_of: :pessoa
    
    paginates_per 30;

    validates :cpf_cnpj, cpf_cnpj: true, presence: true, uniqueness: true
    #validates :nome, :rg_ie, :celular, :cep, :endereco, presence: true

    def to_s
        self.nome;
    end

    # :tipo, :cpf_cnpj, :apelido, :bairro , :celular, :cep, :complemento, 
    # :datacadastro, :endereco, :nome, :numero, :rg_ie, :telefone, :civil, :cpfconj, 
    # :dtnascimento, :dtnascimentoconj, :emprego, :nomeconj, :rgconjuge, :salario, 
    # :pessoacontato, :telefonecontato, :cod_cidade, :credito, :nrcadpro, :dtconsulta, 
    # :registradoscpc, :email

end
