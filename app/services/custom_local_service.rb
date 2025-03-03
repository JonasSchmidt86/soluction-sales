class CustomLocalService < ActiveStorage::Service::DiskService
    def path_for(key)
      # Usa o key diretamente sem criar subpastas
      File.join(root, key)
    end
  end
  