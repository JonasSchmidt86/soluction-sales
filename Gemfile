source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.4'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1', '>= 6.1.7.3'

# pg postgres
# gem 'pg', '1.4.0'
gem 'pg', '~> 1.1.1'

# Use Puma as the app server
gem 'puma', '~> 3.11'

# Use SCSS for stylesheets
gem 'sass', '~> 3.2.0'

gem 'railties' #, '~> 3.2.0'
gem 'rails-i18n', '~> 7.0.4'
gem 'coffee-rails', '~> 4.2'

# Use Uglifier as compressor for JavaScript assets
# gem 'uglifier', '>= 1.3.0'

# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views

# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'


# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false
gem 'devise'
gem 'tty-spinner'
gem 'kaminari'
gem 'kaminari-i18n'
gem 'jquery_mask_rails', '~> 0.1.0'
gem "cocoon" # gem para add no formulario pergunta as respostas dinamicamente 

# ---- estava dentro do development
gem 'listen', '>= 3.0.5', '< 3.2'
# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
gem 'spring'
gem 'spring-watcher-listen', '~> 2.0.0'
# ---- 

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'capistrano', '~> 3.10'
  gem 'capistrano-rvm'
  gem 'capistrano-bundler', '~> 1.5'
  gem 'capistrano-rails', '~> 1.4'
  
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of chromedriver to run system tests with Chrome
  gem 'chromedriver-helper'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
