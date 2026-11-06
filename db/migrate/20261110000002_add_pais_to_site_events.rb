class AddPaisToSiteEvents < ActiveRecord::Migration[7.1]
  # Pais estimado do visitante (GeoIP local). Guarda o CODIGO (chave estavel, usada
  # para agrupar e separar Brasil x exterior) e o NOME em pt-BR (so para exibir):
  # a MaxMind desaconselha usar nomes como chave, pois podem mudar entre versoes.
  def change
    unless column_exists?(:site_events, :pais)
      add_column :site_events, :pais, :string, limit: 2,
                 comment: "ISO 3166-1 alpha-2 estimado por GeoIP (ex.: BR, US)"
    end

    unless column_exists?(:site_events, :pais_nome)
      add_column :site_events, :pais_nome, :string, limit: 80,
                 comment: "nome do pais em pt-BR (apenas exibicao)"
    end
  end
end
