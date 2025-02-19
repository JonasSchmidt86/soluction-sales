class StorageService < ActiveStorage::Service

  def path_for(key)
    # Usa o key diretamente sem criar subpastas
    File.join(root, key)
  end
  
end
  