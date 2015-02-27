require 'bundler'
Bundler.setup
require 'sinatra'
require "sinatra/json"
require 'yaml'
require 'yajl'
require 'mongo'
require 'redis'

Dir['./components/**/*.rb'].each { |f| require(f) }
Dir['./*.rb'].each { |f| require(f) }
