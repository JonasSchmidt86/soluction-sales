# app/services/storage_service.rb
class StorageService < ActiveStorage::Service
    # Construct a dynamic path based on the provided key
    def self.dynamic_path(key)
        # Adapt this as needed to fit your requirements
        parts = key.split('/').compact.reject(&:empty?)

        return nil if parts.empty?

        destination_directory = File.join(key)
        # destination_directory = File.join(Dir.pwd, 'xml', *parts)
        # FileUtils.mkdir_p(destination_directory) unless File.directory?(destination_directory)

        return destination_directory
    end

    # Override the upload method to use dynamic paths
    def upload(key, io, checksum: nil)
        path = self.class.dynamic_path(key)

        return unless path

        super(path, io, checksum: checksum)
    end
  end
  