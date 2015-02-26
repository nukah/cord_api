require 'bundler'
Bundler.setup

Dir[File.join('./components/**/*.rb')].each { |f| require(f) }
Dir[File.join('./models/**/*.rb')].each { |f| require(f) }
Dir[File.join('./*.rb')].each { |f| require(f) }
