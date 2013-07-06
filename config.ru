require 'bundler'
Bundler.require
require File.join(File.dirname(__FILE__), '.', 'omnivore')
run Sinatra::Application