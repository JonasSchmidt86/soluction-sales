# Corrige pessoas vinculadas a uma cidade HOMONIMA de UF errada (ex.: Toledo/MG
# no lugar de Toledo/PR), causada pelo cadastro por CEP que casava a cidade so
# pelo NOME (bug corrigido na view/JS). Reatribui o cod_cidade correto.
#
# Idempotente: rodar de novo nao faz nada se ja estiver certo.
# Seguro: por padrao e DRY-RUN (so lista); so grava com APPLY=1.
#
# Uso:
#   # ver o que seria alterado (nao grava):
#   rails cidade:corrige_homonima
#   # aplicar de verdade:
#   APPLY=1 rails cidade:corrige_homonima
#
# Parametros (env), com defaults para o caso Toledo MG->PR:
#   DE=5294   cod_cidade errado (origem)
#   PARA=43   cod_cidade correto (destino)
namespace :cidade do
  desc "Corrige pessoas numa cidade homonima de UF errada (DRY-RUN; APPLY=1 grava)"
  task corrige_homonima: :environment do
    de    = (ENV["DE"]   || "5294").to_i   # Toledo/MG (errada)
    para  = (ENV["PARA"] || "43").to_i     # Toledo/PR (correta)
    apply = ENV["APPLY"].to_s == "1"

    origem  = Cidade.find_by(cod_cidade: de)
    destino = Cidade.find_by(cod_cidade: para)
    abort("Cidade de origem #{de} nao encontrada") if origem.nil?
    abort("Cidade de destino #{para} nao encontrada") if destino.nil?

    puts "DE  : #{de} = #{origem.nome}/#{origem.estado&.sigla} (IBGE #{origem.cod_municipio})"
    puts "PARA: #{para} = #{destino.nome}/#{destino.estado&.sigla} (IBGE #{destino.cod_municipio})"
    puts "Modo: #{apply ? 'APLICAR (grava)' : 'DRY-RUN (nao grava)'}"
    puts "-" * 60

    pessoas = Pessoa.where(cod_cidade: de)
    total = pessoas.count
    puts "Pessoas vinculadas a #{de}: #{total}"

    # Seguranca: so migra quem NAO tem CEP de outra UF. Para Toledo o CEP de PR
    # fica na faixa 80-87; CEP de MG (38) seria mantido. Pessoas sem CEP sao
    # migradas tambem (nenhuma legitima de MG neste caso), mas listadas a parte.
    mantidas = []
    migrar   = []
    pessoas.find_each do |p|
      cep = p.cep.to_s.gsub(/\D/, "")
      prefixo = cep[0, 2].to_i
      # Mantém apenas quem tem CEP claramente de outra UF (fora de 80-87).
      if cep.length >= 5 && !(prefixo >= 80 && prefixo <= 87)
        mantidas << p
      else
        migrar << p
      end
    end

    puts "A migrar p/ #{para}: #{migrar.size}  |  mantidas (CEP de outra UF): #{mantidas.size}"
    unless mantidas.empty?
      puts "MANTIDAS (confira manualmente):"
      mantidas.each { |p| puts "  cod_pessoa=#{p.cod_pessoa} #{p.nome} cep=#{p.cep}" }
    end

    if apply
      alterados = 0
      ActiveRecord::Base.transaction do
        migrar.each do |p|
          p.update_columns(cod_cidade: para) # UF/IBGE derivam da cidade
          alterados += 1
        end
      end
      puts "-" * 60
      puts "OK: #{alterados} pessoa(s) migrada(s) de #{de} para #{para}."
    else
      puts "-" * 60
      puts "DRY-RUN: nada gravado. Rode novamente com APPLY=1 para aplicar."
    end
  end
end
