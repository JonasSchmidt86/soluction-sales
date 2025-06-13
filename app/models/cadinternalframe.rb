class Cadinternalframe < ApplicationRecord
  self.primary_key = 'cod_frame'
  
  has_many :framefuncionarios, foreign_key: 'cod_frame'
  
  validates :jmenu, presence: true, length: { maximum: 100 }
  validates :nminternalframe, presence: true, length: { maximum: 100 }
  validates :tituloframe, presence: true, length: { maximum: 100 }
  
  # Método para obter o próximo código disponível
  def self.next_code
    maximum(:cod_frame).to_i + 1
  end
  
  # Método para obter a rota associada ao frame
  def get_route_path
    # Se já existe uma URL definida, use-a
    return url if url.present?
    
    # Caso contrário, tente construir a rota a partir do nome interno
    begin
      # Tenta construir o caminho da rota a partir do nome interno
      Rails.application.routes.url_helpers.send("collaborators_backoffice_#{nminternalframe.downcase}_path") rescue nil
    rescue
      # Se não conseguir encontrar a rota, retorna nil
      nil
    end
  end
end