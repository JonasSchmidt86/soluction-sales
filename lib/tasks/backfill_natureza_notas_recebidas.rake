# Preenche natureza_operacao (natOp) nas notas_recebidas ja gravadas sem esse
# campo. A natureza so existe no XML; muitas notas foram registradas sem baixar
# o XML (via "Ver entradas na SEFAZ" / "Salvar por chave"), entao ficaram sem.
#
# Para cada nota sem natureza:
#   - se ja tem XML anexado: extrai dali (nao toca na SEFAZ);
#   - senao, baixa o XML da SEFAZ (a menos que SEM_SEFAZ=1), anexa e extrai.
# Idempotente: pode rodar varias vezes.
#
# Uso:
#   rails notas_recebidas:backfill_natureza                 # todas as empresas
#   EMPRESA=2 rails notas_recebidas:backfill_natureza       # so uma empresa
#   SEM_SEFAZ=1 rails notas_recebidas:backfill_natureza     # so o que tem XML local
namespace :notas_recebidas do
  desc "Backfill de natureza_operacao nas notas recebidas (le/baixa o XML)"
  task backfill_natureza: :environment do
    baixar = ENV["SEM_SEFAZ"].to_s != "1"

    empresas = if ENV["EMPRESA"].present?
                 Empresa.where(cod_empresa: ENV["EMPRESA"].to_i)
               else
                 # so empresas que tem notas recebidas sem natureza
                 cods = NotaRecebida.where("natureza_operacao IS NULL OR natureza_operacao = ''")
                                    .distinct.pluck(:cod_empresa)
                 Empresa.where(cod_empresa: cods)
               end

    total_preenchidas = 0
    total_sem_xml     = 0
    total_falhas      = 0

    empresas.find_each do |empresa|
      res = Fiscal::NotasRecebidasService.new(empresa)
                                         .preencher_naturezas_faltantes!(baixar_xml: baixar)
      puts "Empresa #{empresa.cod_empresa}: preenchidas=#{res[:preenchidas]} sem_xml=#{res[:sem_xml]} falhas=#{res[:falhas]}"
      total_preenchidas += res[:preenchidas]
      total_sem_xml     += res[:sem_xml]
      total_falhas      += res[:falhas]
    end

    puts "---"
    puts "TOTAL -> preenchidas: #{total_preenchidas} | sem XML disponivel: #{total_sem_xml} | falhas: #{total_falhas}"
    puts "(SEM_SEFAZ=1 pula o download; rode sem essa flag para buscar os XML faltantes)" unless baixar
  end
end
