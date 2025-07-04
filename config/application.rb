require_relative 'boot'

# require 'rails/all'

# Desabilitando configurações padrão (generators) aula 4
# Customizando seu workflow
# https://guides.rubyonrails.org/generators.html#customizing-your-workflow

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
require 'logger'

# require "rails/test_unit/railtie" 

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SoluctionSales

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1
    
    config.time_zone = 'Brasilia'
    config.active_record.default_timezone = :utc

    # config.active_storage.service = :local
    config.i18n.default_locale = 'pt-BR'
    
    config.i18n.default_locale = :'pt-BR'
    config.i18n.available_locales = [:'pt-BR', :en]


    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.generators.system_tests = nil
    # config.logger = Logger.new(STDOUT)
    # config.log_level = :debug
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins 'https://www.moveisrosa.shop'
        resource '*', headers: :any, methods: [:get, :post, :patch, :put, :delete, :options, :head], credentials: true
      end
    end
  end
  

  
end
