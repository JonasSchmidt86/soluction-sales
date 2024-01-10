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
         show_spinner("Cadastrando o colaborador padrão...") { %x(rails dev:add_default_collaborator) } 
        # show_spinner("Cadastrando o usuário padrão...") { %x(rails dev:add_default_user) }
      else
        puts "Você não está em ambiente de desenvolvimento!"
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
  