require 'bundler'
Bundler.require
require File.join(File.dirname(__FILE__), '.', 'omnivore')

if `redis-cli ping`.strip == "PONG" #check if redis instance is running
  run Sinatra::Application
end