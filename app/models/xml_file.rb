# app/models/xml_file.rb
class XmlFile < ApplicationRecord
  
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
        self.file.attach(existing_blob)
      else
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

  
  # def attach_file_with_custom_service(io, filename, company)
  #   service = StorageService.new
  
  #   begin
  #     io.rewind
  
  #     # Gera um nome único baseado na empresa e nome do arquivo
  #     sanitized_company_name = company.nome.parameterize(separator: "_")
  #     # custom_key = "#{sanitized_company_name}/#{"date.year"}/#{filename}" # Usando underscore para evitar subdiretórios
  #     custom_key = "#{sanitized_company_name}/#{Date.today.year}/#{filename}"

  #     # Verifica se o Blob já existe
  #     blob = ActiveStorage::Blob.find_by(key: custom_key)

  #     unless blob
  #       # Cria e faz o upload do Blob
  #       blob = ActiveStorage::Blob.create_and_upload!(
  #         key: custom_key,
  #         io: io,
  #         filename: filename,
  #         content_type: io.content_type || 'application/octet-stream',
  #         metadata: {}, # Metadado extra, # Pode incluir metadados personalizados
  #         service_name: :xml_storage  # Nome do serviço personalizado
  #       )
  #     end

  #     # Associa o Blob ao modelo
  #     self.file.attach(blob)
  #     Rails.logger.info("Blob criado ou recuperado com chave: #{blob.key}")
  #   rescue StandardError => e
  #     Rails.logger.error("Erro ao fazer upload do arquivo: #{e.message}")
  #     raise
  #   end
  # end
  
  private

  # Sobrescreva o método `service_name` dinamicamente
  # def file_service_name
  #   if empresa.custom_storage_enabled?
  #     :xml_storage
  #   else
  #     :local
  #   end
  # end

end
  