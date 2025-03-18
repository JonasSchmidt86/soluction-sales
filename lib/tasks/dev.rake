namespace :dev do

# para executar 
# rails dev:setup


  DEFAULT_PASSWORD = 123456
  DEFAULT_FILES_PATH = File.join(Rails.root, 'lib', 'tmp')
  
    desc "Configura o ambiente de desenvolvimento"

    task setup: :environment do
      if Rails.env.development?
        # show_spinner("Apagando BD...") { %x(rails db:drop) } 
        # show_spinner("Criando BD...") { %x(rails db:create) } 
        
        show_spinner("Migrando BD...") { %x(rails db:migrate) } 
        # show_spinner("Cadastrando o Cidade padrão...") { %x(rails dev:add_default_cidade) } 
        # show_spinner("Cadastrando o Pessoa padrão...") { %x(rails dev:add_default_pessoa) } 
        # show_spinner("Cadastrando o Empresa padrão...") { %x(rails dev:add_default_empresa) } 
        # show_spinner("Cadastrando o Funcionario padrão...") { %x(rails dev:add_default_funcionario) } 
        show_spinner("Cadastrando o colaborador padrão...") { %x(rails dev:add_default_collaborator) } 

        # show_spinner("Cadastrando o usuário padrão...") { %x(rails dev:add_default_user) }
      else
        puts "Você não está em ambiente de desenvolvimento!"
        show_spinner("Migrando BD...") { %x(rails db:migrate) } 
        show_spinner("Cadastrando o colaborador padrão...") { %x(rails dev:add_default_collaborator) } 
      end
    end
  
    desc "Adiciona o colaborador padrão"
    task add_default_collaborator: :environment do
      Collaborator.create!(
        email: 'admin@admin.com',
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD,
        cod_funcionario: 1,
        cod_empresa: 2
      )
    end
    task add_default_cidade: :environment do
      Cidade.create!(
        cod_cidade: 1,
        nome: "MARIPA"
      )
    end
    task add_default_empresa: :environment do
      Empresa.create!(
        cod_empresa: 1,
        ativo: true,
        cpf_cnpj: "14993084000116",
        endereco: "Avenida farrapos",
        inscricaoestadual: "0",
        logotipo: "",
        nome: "MOVEIS ROSA",
        numero: "1309",
        cod_cidade: 1,
        cod_pessoa: 1
      )
    end
    task add_default_pessoa: :environment do
      Pessoa.create!(
        tipo: "F",
        cpf_cnpj: "05903985980",
        apelido: "JONAS SCHMIDT",
        bairro: "ALVORADA",
        celular: "(45)99134-8690",
        cep:  "85960000",
        complemento: "MOVEIS ROSA",
        datacadastro: "2012-07-18",
        endereco: "AVENIDA MARIPA",
        nome: "JONAS SCHMIDT",
        numero: "2159",
        rg_ie: "827771620",
        telefone: "(45)3254-2753",
        civil: "0",
        cpfconj: "",
        dtnascimento: "1986-09-10",
        dtnascimentoconj: "1993-12-29",
        emprego: "MOVEIS ROSA",
        nomeconj: "ALINE WERNER",
        rgconjuge: "",
        salario: 0.00,
        pessoacontato: "",
        cod_cidade: 1,
        registradoscpc: false,
        email: "schmidt_jonas@hotmail.com"
      )
    

    end
    task add_default_funcionario: :environment do
      Funcionario.create!(
        ativo: true,
        datacontrato: "2012-06-01",
        salario: 1000.00,
        senha: "jonas1922",
        usuario: "JONAS",
        cod_permissao: 1,
        cod_pessoa: 1
      )
    end
  
    desc "Adiciona o usuário padrão"
    task add_default_user: :environment do
      User.create!(
        email: 'user@user.com',
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD
      )
    end
  
    private 

      def show_spinner(msg_start, msg_end = "Concluído!")
        spinner = TTY::Spinner.new("[:spinner] #{msg_start}")
        spinner.auto_spin
        yield
        spinner.success("(#{msg_end})")
      end
  end 
  