# app/models/xml_file.rb
class XmlFile < ApplicationRecord
  
  has_one_attached :file, service: :local_custom
    
  belongs_to :pessoa, class_name: 'Pessoa', foreign_key: 'pessoa_id', optional: true
  accepts_nested_attributes_for :pessoa, allow_destroy: false
  
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'empresa_id', optional: true
  accepts_nested_attributes_for :empresa, allow_destroy: false
  
  belongs_to :compra, class_name: 'Compra', foreign_key: 'compra_id', optional: true, autosave: true
  accepts_nested_attributes_for :compra, allow_destroy: false

  paginates_per 30
  
  private

  # Sobrescreva o método `service_name` dinamicamente
  def file_service_name
    if empresa.custom_storage_enabled?
      :local_custom
    else
      :local
    end
  end

end
  