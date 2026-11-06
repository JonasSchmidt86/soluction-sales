class CreateSiteEvents < ActiveRecord::Migration[7.1]
  # Eventos de interacao dos clientes no site publico (portfolio/produto).
  # NAO guarda IP nem user-agent (decisao de privacidade): o IP e usado apenas
  # no momento do registro para resolver cidade/estado via GeoIP e descartado.
  def change
    return if table_exists?(:site_events)

    create_table :site_events do |t|
      t.string  :event_type, null: false, limit: 20,
                comment: "view_portfolio | view_produto | click_whatsapp | busca"
      t.bigint  :cod_produto, comment: "produto do evento (view_produto / click_whatsapp)"
      t.string  :termo_busca, limit: 120, comment: "termo normalizado (evento busca)"
      t.string  :visitor_id,  null: false, limit: 40, comment: "id anonimo do cookie"
      t.string  :cidade,      limit: 120
      t.string  :estado,      limit: 2
      t.integer :duracao_seg, comment: "tempo de permanencia no produto (segundos)"
      t.timestamp :created_at, default: -> { 'CURRENT_TIMESTAMP' }, null: false
    end

    add_index :site_events, [:event_type, :created_at], name: "idx_site_events_tipo_data"
    add_index :site_events, :cod_produto,               name: "idx_site_events_produto"
    add_index :site_events, [:visitor_id, :created_at], name: "idx_site_events_visitor_data"
    add_index :site_events, :termo_busca,               name: "idx_site_events_termo"
  end
end
