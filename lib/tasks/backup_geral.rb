# lib/tasks/backup_geral.rb

require 'fileutils'

# === CONFIGURAÇÕES DO PG_DUMP ===
USER_DB = "jonas"
DB_NAME = "moveisrosa"
TABELAS_DUMP = %w[
  public.active_storage_blobs
  public.active_storage_attachments
  public.active_storage_variant_records
  public.custom_reports
  public.produto_imagens
  public.whatsapp_contacts
  public.collaborators
]

# === CONFIGURAÇÕES DO BACKUP GERAL ===
backup_dir = Rails.root.join('backup')
FileUtils.mkdir_p(backup_dir)
file_path = backup_dir.join("backup_geral_#{Time.now.strftime('%Y%m%d_%H%M%S')}.sql")

puts "🗄️ Iniciando backup geral para: #{file_path}"

File.open(file_path, 'w') do |file|

  # === 1. SQL via ActiveRecord - Produtos ===
  produtos = Produto.where.not(titulo: [nil, '']).where.not(descricao: [nil, ''])
  puts "🔹 Produtos encontrados: #{produtos.count}"
  connection = ActiveRecord::Base.connection

  produtos.find_each do |produto|
    cod_produto = produto.cod_produto
    titulo      = connection.quote(produto.titulo)
    descricao   = connection.quote(produto.descricao)

    sql = <<-SQL
-- Produto cod_produto=#{cod_produto}
UPDATE produto
SET titulo = #{titulo},
    descricao = #{descricao}
WHERE cod_produto = #{cod_produto};
    SQL

    file.puts sql.strip
  end

  file.puts "\n-- Fim do backup de produtos\n\n"

  # === 2. SQL via ActiveRecord - Empresaprodutos ===
  empresaprodutos = Empresaproduto.where(publicado: true)
  puts "🔹 Empresaprodutos encontrados: #{empresaprodutos.count}"

  empresaprodutos.find_each do |registro|
    id           = registro.id
    cod_cor      = registro.cod_cor
    cod_empresa  = registro.cod_empresa
    cod_produto  = registro.cod_produto
    publicado    = registro.publicado ? 'true' : 'false'
    valor_site   = registro.valor_site || 0

    sql = <<-SQL
-- Empresaproduto id=#{id}
UPDATE empresaproduto
SET publicado = #{publicado},
    valor_site = #{valor_site}
WHERE cod_empresa = #{cod_empresa}
  AND cod_produto = #{cod_produto}
  AND cod_cor = #{cod_cor};
    SQL

    file.puts sql.strip
  end

  file.puts "\n-- Fim do backup de empresaprodutos\n\n"

  # === 3. Dump de tabelas usando pg_dump ===
  puts "📤 Exportando tabelas com pg_dump..."


  TABELAS_DUMP.each do |tabela|
    puts "🔸 Exportando: #{tabela}"
    cmd = %(pg_dump -U #{USER_DB} -d #{DB_NAME} -t #{tabela} --data-only --inserts)
    dump_output = `#{cmd}`
    if $?.success?
      file.puts "\n-- Dump da tabela #{tabela}\n"
      file.puts dump_output
    else
      puts "❌ Erro ao exportar tabela: #{tabela}"
      file.puts "\n-- ERRO ao exportar tabela #{tabela}\n"
    end
  end

  ENV['PGPASSWORD'] = nil
  puts "✅ Dump de tabelas concluído"
end

puts "🎉 Backup completo salvo em: #{file_path}"
