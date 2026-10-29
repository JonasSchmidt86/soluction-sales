# Mantem nota_recebida.cod_compra coerente com as compras reais.
#
# Antes, nada atualizava nota_recebida.cod_compra depois que a compra era criada
# pela Importacao de XML (a lista de Notas Recebidas continuava mostrando o
# botao Importar em vez do carrinho) e, ao contrario, nada desligava a nota
# quando a compra era cancelada/excluida. Daqui em diante o Compra e o
# ComprasController#destroy cuidam disso; esta tarefa corrige o que ficou para tras.
#
# Passo 1 - SOLTA: nota ligada a compra CANCELADA ou INEXISTENTE volta a ficar
#           sem compra (cod_compra = NULL) e pode ser importada de novo.
# Passo 2 - LIGA: nota cujo XML (xml_file_id) ja aponta para uma compra NAO
#           cancelada (xml_files.compra_id) e esta sem compra e ligada a ela.
#           Criterio exato pelo XML, sem adivinhar por numero de NF.
# Idempotente: pode rodar varias vezes.
#
# Uso:
#   rails notas_recebidas:vincular_compras                # todas as empresas
#   EMPRESA=2 rails notas_recebidas:vincular_compras      # so uma empresa
#   DRY_RUN=1 rails notas_recebidas:vincular_compras      # so mostra, nao grava
namespace :notas_recebidas do
  desc "Sincroniza o vinculo nota recebida x compra (solta canceladas/excluidas, liga as ja compradas)"
  task vincular_compras: :environment do
    dry = ENV["DRY_RUN"].to_s == "1"
    base = NotaRecebida.all
    base = base.where(cod_empresa: ENV["EMPRESA"].to_i) if ENV["EMPRESA"].present?
    prefixo = dry ? "[DRY_RUN] " : ""

    # ---- Passo 1: soltar notas ligadas a compra cancelada/inexistente ----
    soltas = 0
    base.where.not(cod_compra: nil).find_each do |nota|
      compra = Compra.find_by(cod_compra: nota.cod_compra)
      motivo = if compra.nil? then "compra #{nota.cod_compra} nao existe mais"
               elsif compra.cancelada then "compra #{compra.cod_compra} cancelada"
               end
      next unless motivo

      puts "SOLTA nota #{nota.cod_nota_recebida} (NF #{nota.numero}, #{nota.emitente_nome}) - #{motivo}"
      nota.update_column(:cod_compra, nil) unless dry
      soltas += 1
    end

    # ---- Passo 1b: soltar XML preso a compra cancelada ----
    # A tela de Importacao de XML religava o XML a compra pelo numero da NF,
    # inclusive a compras canceladas; o XML sumia da lista e nao dava para
    # importar de novo. A tela foi corrigida; aqui solta o que ficou preso.
    xml_soltos = 0
    xmls = XmlFile.joins(:compra).where(compra: { cancelada: true })
    xmls = xmls.where(empresa_id: ENV["EMPRESA"].to_i) if ENV["EMPRESA"].present?
    xmls.find_each do |xml|
      puts "SOLTA xml #{xml.id} (#{xml.name}) - preso a compra cancelada #{xml.compra_id}"
      xml.update_column(:compra_id, nil) unless dry
      xml_soltos += 1
    end

    # ---- Passo 2: ligar notas cujo XML ja virou compra ----
    ligadas = 0
    ignoradas = 0
    base.where(cod_compra: nil).joins(:xml_file).where.not(xml_files: { compra_id: nil }).find_each do |nota|
      compra = Compra.find_by(cod_compra: nota.xml_file.compra_id)
      if compra.nil? || compra.cancelada
        ignoradas += 1
        next
      end
      puts "LIGA  nota #{nota.cod_nota_recebida} (NF #{nota.numero}, #{nota.emitente_nome}) -> compra #{compra.cod_compra}"
      nota.update_column(:cod_compra, compra.cod_compra) unless dry
      ligadas += 1
    end

    puts "---"
    puts "#{prefixo}notas soltas: #{soltas} | xml soltos: #{xml_soltos} | ligadas: #{ligadas} | ignoradas (XML aponta p/ compra inexistente/cancelada): #{ignoradas}"
  end
end
