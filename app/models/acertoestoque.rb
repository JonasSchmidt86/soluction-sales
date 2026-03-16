class Acertoestoque < ApplicationRecord
  self.table_name = "acertosestoque"
  self.primary_key = "codigo"

  belongs_to :produto, foreign_key: 'cod_produto', primary_key: 'cod_produto'
  belongs_to :cor, class_name: 'Core', foreign_key: 'cod_cor', primary_key: 'cod_cor'
  belongs_to :empresa, foreign_key: 'cod_empresa', primary_key: 'cod_empresa'

  paginates_per 30

  # atributo virtual
  def full_codigo
    [self.cod_produto, self.cod_cor].join('-')
  end

  def full_cod_cor
    [self.cor&.nmcor, self.cod_cor].join(' - ')
  end 
end
