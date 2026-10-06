# Seed idempotente das operacoes fiscais basicas do modulo fiscal.
# Rode com: bundle exec rails runner "load Rails.root.join('db/seeds/fiscal.rb')"
# ou via db:seed (referenciado em db/seeds.rb).

operacoes = [
  # --- Operacoes ja existentes (mantidas) ---
  { nome: "Venda",              tipo: "saida",   modelo: 65, natureza_operacao: "Venda de mercadoria" },
  { nome: "Venda (NF-e)",       tipo: "saida",   modelo: 55, natureza_operacao: "Venda de mercadoria" },
  { nome: "Devolucao de venda", tipo: "entrada", modelo: 55, natureza_operacao: "Devolucao de venda" },
  { nome: "Devolucao de compra",tipo: "saida",   modelo: 55, natureza_operacao: "Devolucao de compra" },
  { nome: "Transferencia",      tipo: "saida",   modelo: 55, natureza_operacao: "Transferencia entre estabelecimentos" },
  { nome: "NF avulsa",          tipo: "saida",   modelo: 55, natureza_operacao: "Venda de mercadoria" },

  # --- Naturezas adicionais (cadastro de conveniencia; CFOP e quem a SEFAZ valida) ---
  { nome: "Remessa",            tipo: "saida",   modelo: 55, natureza_operacao: "Remessa" },
  { nome: "Devolucao",          tipo: "entrada", modelo: 55, natureza_operacao: "Devolucao" },
  { nome: "Retorno",            tipo: "entrada", modelo: 55, natureza_operacao: "Retorno de mercadoria" },
  { nome: "Industrializacao",   tipo: "saida",   modelo: 55, natureza_operacao: "Industrializacao" },
  { nome: "Cobranca",           tipo: "saida",   modelo: 55, natureza_operacao: "Cobranca" },
  { nome: "Compra",             tipo: "entrada", modelo: 55, natureza_operacao: "Compra de mercadoria" },
  { nome: "Venda de Mercadoria",tipo: "saida",   modelo: 55, natureza_operacao: "Venda de mercadoria" },
  { nome: "Prestacao de Servico", tipo: "saida", modelo: 55, natureza_operacao: "Prestacao de servico" },
  { nome: "Remessa para Conserto", tipo: "saida", modelo: 55, natureza_operacao: "Remessa para conserto" },
  { nome: "Baixa de estoque por perda, roubo ou deterioracao", tipo: "saida", modelo: 55, natureza_operacao: "Baixa de estoque por perda, roubo ou deterioracao" }
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
