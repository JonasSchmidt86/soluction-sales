class Pessoa < ApplicationRecord

    after_create :link_atendimentos

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

    # CPF/CNPJ: exigido e validado em cadastros NOVOS ou quando o valor e
    # ALTERADO. Registros legados (clientes antigos sem CPF ou com CPF invalido,
    # importados do sistema anterior) NAO sao bloqueados ao serem re-salvos — ex.:
    # editar uma venda nao deve falhar por causa do CPF do cliente que nem mudou.
    # A unicidade so e checada quando ha valor (nil/"" nao conflita).
    validates :cpf_cnpj, cpf_cnpj: true, presence: true,
              if: -> { new_record? || will_save_change_to_cpf_cnpj? }
    validates :cpf_cnpj, uniqueness: true,
              if: -> { cpf_cnpj.present? && (new_record? || will_save_change_to_cpf_cnpj?) }
    #validates :nome, :rg_ie, :celular, :cep, :endereco, presence: true

    def to_s
        self.nome;
    end

    # --- Helpers fiscais (UF e municipio via Cidade->Estado) ---

    # Sigla da UF (ex: "PR"). nil se nao houver cidade/estado.
    def uf
        cidade&.estado&.sigla
    end

    # Codigo IBGE do municipio (7 digitos) exigido no XML da NF-e.
    def cod_municipio_ibge
        cidade&.cod_municipio
    end

    # true = pessoa juridica (tipo "J"); usado para decidir NF-e x NFC-e e IE.
    def pessoa_juridica?
        tipo.to_s.upcase == "J"
    end

    def link_atendimentos
        numeros = [self.telefone, self.celular]
            .compact
            .map { |n| n.gsub(/\D/, '') }
            .reject(&:blank?)

        return if numeros.empty?

        atendimentos = Atendimento
            .where(customer_id: nil)
            .where(
                numeros.map { "REGEXP_REPLACE(phone, '[^0-9]', '', 'g') = ?" }.join(' OR '),
                *numeros
            )

        return if atendimentos.empty?

        atendimentos.update_all(customer_id: self.cod_pessoa)

        if self.origem_id.blank?
            primeira_origem = atendimentos.order(:created_at).first&.origem_id
            self.update_column(:origem_id, primeira_origem) if primeira_origem.present?
        end
    end

    # :tipo, :cpf_cnpj, :apelido, :bairro , :celular, :cep, :complemento, 
    # :datacadastro, :endereco, :nome, :numero, :rg_ie, :telefone, :civil, :cpfconj, 
    # :dtnascimento, :dtnascimentoconj, :emprego, :nomeconj, :rgconjuge, :salario, 
    # :pessoacontato, :telefonecontato, :cod_cidade, :credito, :nrcadpro, :dtconsulta, 
    # :registradoscpc, :email

end
