# config valid for current version and patch releases of Capistrano
lock "~> 3.17.2"

after 'deploy:publishing', 'deploy:restart'

namespace :deploy do
    task :restart do
      invoke 'unicorn:stop'
      invoke 'unicorn:start'
    end
end


set :application, 'soluction-sales'              # Nome da sua aplicação          
set :repo_url, 'https://github.com/JonasSchmidt86/soluction_sales.git'    # Repositório git do seu projeto
set :deploy_to, '/var/www/soluction.sales'
set :branch, 'main'
set :keep_releases, 5

set :format, :airbrussh
set :log_level, :debug
append :linked_files, "config/database.yml"
append :linked_dirs, "storage", "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
