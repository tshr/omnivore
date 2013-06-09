require 'sinatra'
require 'redis'

redis = Redis.new

get '/' do
  erb :index
end

get '/feed/:feed_url' do
  content_type 'text/xml'
  feed = redis.get(params[:feed_url])
  if feed
    "<data>#{feed}</data>"
  else
    "<error>no feed data for #{params[:feed_url]}</error>"
  end
end