class Core < ApplicationRecord

    self.table_name = "cores"
    self.primary_key = 'cod_cor'

    has_many :empresaprodutos, :class_name => 'Empresaproduto', :foreign_key => 'cod_cor', inverse_of: :cor, dependent: :restrict_with_error
    
    has_many :produto_imagens, :class_name =>'ProdutoImagem', foreign_key: 'cod_cor', inverse_of: :cor, dependent: :restrict_with_error

    validates :nmcor, presence: { message: "não pode ficar em branco" }, 
                    uniqueness: { case_sensitive: false, message: "já está cadastrado" }

    def nmcor_cod
        return [self.nmcor, self.cod_cor].join(' - ')
    end
    
    def to_s
        nmcor;
    end
    
    paginates_per 30;

end
