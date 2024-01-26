# app/models/xml_file.rb
class XmlFile < ApplicationRecord
  
  has_one_attached :file, service: :local_custom
    
  belongs_to :pessoa, class_name: 'Pessoa', foreign_key: 'pessoa_id', optional: true
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'empresa_id', optional: true
  
  paginates_per 30
  
end
  