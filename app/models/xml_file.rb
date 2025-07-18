# app/models/xml_file.rb
class XmlFile < ApplicationRecord
  
  before_destroy :purge_file

  has_one_attached :file, dependent: :destroy, service: :xml_storage
    
  belongs_to :pessoa, class_name: 'Pessoa', foreign_key: 'pessoa_id', optional: true
  accepts_nested_attributes_for :pessoa, allow_destroy: false
  
  belongs_to :empresa, class_name: 'Empresa', foreign_key: 'empresa_id', optional: true
  accepts_nested_attributes_for :empresa, allow_destroy: false
  
  belongs_to :compra, class_name: 'Compra', foreign_key: 'compra_id', optional: true, autosave: true
  accepts_nested_attributes_for :compra, allow_destroy: false

  paginates_per 30
  
  def attach_file_with_custom_service(io, filename, company)
    begin
      io.rewind
      sanitized_company_name = company.nome.parameterize(separator: "_")
      custom_key = "#{sanitized_company_name}/#{Date.today.year}/#{filename}"
  
      # Verifica se já existe
      existing_blob = ActiveStorage::Blob.find_by(key: custom_key)
  
      if existing_blob
        Rails.logger.info("Reusando blob existente com chave: #{custom_key}")
        self.file.attach(existing_blob)
      else
        # Anexa o novo arquivo
        self.file.attach(
          io: io,
          filename: filename,
          content_type: io.content_type || 'application/octet-stream',
          service_name: :xml_storage,
          key: custom_key
        )  
      end    
  
      Rails.logger.info("Arquivo anexado com chave: #{custom_key}")
    rescue StandardError => e
      Rails.logger.error("Erro ao anexar o arquivo: #{e.message}")
      raise
    end
  end

  def local_file_path
    return unless file.attached? && file.blob.present?  
    file.blob.service.send(:path_for, file.key)
  end

  private

  def purge_file
    file.purge_later if file.attached?
  end
  

end
  