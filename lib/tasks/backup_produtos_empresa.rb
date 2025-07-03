# lib/tasks/backup_geral.rb

require 'fileutils'

# Diretório e nome do arquivo de backup
backup_dir = Rails.root.join('backup')
FileUtils.mkdir_p(backup_dir)
file_path = backup_dir.join("backup_geral_#{Time.now.strftime('%Y%m%d_%H%M%S')}.sql")

File.open(file_path, 'w') do |file|

  # === 1. Backup de Produtos ===
  produtos = Produto.where.not(titulo: [nil, '']).where.not(descricao: [nil, ''])
  puts "Produtos encontrados: #{produtos.count}"

  produtos.find_each do |produto|
    cod_produto = produto.cod_produto
    titulo = ActiveRecord::Base.connection.quote(produto.titulo)
    descricao = ActiveRecord::Base.connection.quote(produto.descricao)

    sql = <<-SQL
 -- \n 
-- Produto cod_produto=#{cod_produto} \n
   UPDATE produto
      SET titulo = #{titulo},
          descricao = #{descricao}
    WHERE cod_produto = #{cod_produto};
 
    SQL

    file.puts sql.strip
  end

  file.puts "\n-- Fim do backup de produtos\n"

  # === 2. Backup de Empresaprodutos publicados ===
  empresaprodutos = Empresaproduto.where(publicado: true)
  puts "Empresaprodutos encontrados: #{empresaprodutos.count}"

  empresaprodutos.find_each do |registro|
    id = registro.id
    cod_cor = registro.cod_cor
    cod_empresa = registro.cod_empresa
    cod_produto = registro.cod_produto
    publicado = registro.publicado ? 'true' : 'false'
    valor_site = registro.valor_site || 0

    sql = <<-SQL
--\n
-- Empresaproduto id=#{id}
UPDATE empresaproduto
SET publicado = #{publicado},
    valor_site = #{valor_site}
WHERE cod_empresa = #{cod_empresa}
  and cod_produto = #{cod_produto}
  and cod_cor = #{cod_cor};
    SQL

    file.puts sql.strip
  end

  file.puts "\n-- Fim do backup de empresaprodutos\n"
end

puts "✅ Backup unificado salvo em: #{file_path}"
