class ItemOrcamentoFotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "uploads/orcamentos/fotos/#{model.id}"
  end

  version :thumb do
    process resize_to_fill: [400, 400]
  end

  version :medium do
    process resize_to_fill: [600, 600]
  end

  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end
end
