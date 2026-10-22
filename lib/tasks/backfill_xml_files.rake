require "nokogiri"

# Preenche numeronf (nNF) e chave (44 digitos) dos xml_files existentes, lendo
# cada XML anexado. So grava o que estiver vazio (nao sobrescreve). Idempotente.
#
# Uso:
#   rails xml_files:backfill_numeronf            # todos os registros
#   EMPRESA=2 rails xml_files:backfill_numeronf  # so de uma empresa
namespace :xml_files do
  desc "Backfill de numeronf e chave nos xml_files existentes (le o XML anexado)"
  task backfill_numeronf: :environment do
    escopo = XmlFile.all
    escopo = escopo.where(empresa_id: ENV["EMPRESA"].to_i) if ENV["EMPRESA"].present?

    total = escopo.count
    ok = 0
    sem_arquivo = 0
    erro = 0
    puts "Backfill de numeronf/chave em #{total} xml_files..."

    escopo.find_each do |xf|
      next if xf.numeronf.present? && xf.chave.present? # ja preenchido

      path = xf.local_file_path
      unless path && File.exist?(path)
        sem_arquivo += 1
        next
      end

      doc = Nokogiri::XML(File.read(path, encoding: "UTF-8"))
      nnf   = doc.at_xpath('//*[local-name()="ide"]')&.at("nNF")&.text.to_s.strip
      id    = doc.at_xpath('//*[local-name()="infNFe"]')&.[]("Id").to_s.gsub(/\D/, "")
      chave = (id.length == 44 ? id : nil)

      attrs = {}
      attrs[:numeronf] = nnf.presence if xf.numeronf.blank?
      attrs[:chave]    = chave        if xf.chave.blank? && chave
      next if attrs.empty?

      xf.update_columns(attrs)
      ok += 1
    rescue => e
      erro += 1
      Rails.logger.error("[xml_files:backfill] id #{xf.id}: #{e.class} - #{e.message}")
    end

    puts "Atualizados: #{ok} | sem arquivo: #{sem_arquivo} | erros: #{erro}"
  end
end
