class ProdutoImagemUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  
  storage :file
  
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end
  
  def default_url(*args)
    ActionController::Base.helpers.asset_path("fallback/" + [version_name, "default.png"].compact.join('_'))
  end
  
  process resize_to_limit: [800, 800]
  
  version :thumb do
    process resize_to_limit: [200, 200]
  end
  
  version :medium do
    process resize_to_limit: [400, 400]
  end
  
  def extension_allowlist
    %w(jpg jpeg gif png)
  end
  
  def content_type_allowlist
    ['image/jpeg', 'image/png', 'image/gif']
  end
end 