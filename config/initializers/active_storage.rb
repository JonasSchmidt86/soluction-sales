module CustomActiveStorageKey
    def key
      if attributes["key"].present?
        attributes["key"]
      else
        self.key = "#{metadata["company_name"]}/#{Date.today.year}/#{filename}"
      end
    end
  end
  
  Rails.application.config.to_prepare do
    ActiveStorage::Blob.include(CustomActiveStorageKey)
  end
  