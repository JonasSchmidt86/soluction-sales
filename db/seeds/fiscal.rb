# Seed idempotente das operacoes fiscais basicas do modulo fiscal.
# Rode com: bundle exec rails runner "load Rails.root.join('db/seeds/fiscal.rb')"
# ou via db:seed (referenciado em db/seeds.rb).

operacoes = [
  { nome: "Venda",              tipo: "saida",   modelo: 65, natureza_operacao: "Venda de mercadoria" },
  { nome: "Venda (NF-e)",       tipo: "saida",   modelo: 55, natureza_operacao: "Venda de mercadoria" },
  { nome: "Devolucao de venda", tipo: "entrada", modelo: 55, natureza_operacao: "Devolucao de venda" },
  { nome: "Devolucao de compra",tipo: "saida",   modelo: 55, natureza_operacao: "Devolucao de compra" },
  { nome: "Transferencia",      tipo: "saida",   modelo: 55, natureza_operacao: "Transferencia entre estabelecimentos" },
  { nome: "NF avulsa",          tipo: "saida",   modelo: 55, natureza_operacao: "Venda de mercadoria" }
]

operacoes.each do |attrs|
  op = OperacaoFiscal.find_or_initialize_by(nome: attrs[:nome])
  op.tipo = attrs[:tipo]
  op.modelo = attrs[:modelo]
  op.natureza_operacao = attrs[:natureza_operacao]
  op.ativo = true if op.ativo.nil?
  op.save!
  puts "  operacao_fiscal: #{op.nome} (#{op.tipo}/#{op.modelo})"
end

puts "Seed fiscal concluido: #{OperacaoFiscal.count} operacoes."
