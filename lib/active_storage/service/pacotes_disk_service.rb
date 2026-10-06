require "active_storage/service/disk_service"

# DiskService SEM particionamento de pasta, para os PACOTES fiscais ficarem em
# caminho limpo: storage/PACOTES/<empresa>/<AAAA-MM>/<arquivo>, em vez de
# storage/PACOTES/<2c>/<2c>/<key>. Referenciado por storage.yml
# (pacotes_storage: service: PacotesDisk). NAO afeta os demais discos/arquivos.
module ActiveStorage
  class Service::PacotesDiskService < Service::DiskService
    private

    # Sem subpastas de 2 chars: a key ja e o caminho relativo completo.
    def folder_for(_key)
      ""
    end

    def path_for(key)
      File.join(root, key)
    end
  end
end
