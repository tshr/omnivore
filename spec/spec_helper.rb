require 'bundler'
Bundler.require
require File.join(File.dirname(__FILE__), '..', 'omnivore.rb')

set :environment, :test
set :raise_errors, true
set :logging, false

def app
  Sinatra::Application
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.color_enabled = true
end