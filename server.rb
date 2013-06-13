require 'sinatra'
require 'redis'
require 'rest-client'

redis = Redis.new

get '/' do
  erb :index
end

get '/feed' do
  content_type 'text/xml'

  request_url = params[:url]
  feed_hash = redis.hgetall request_url

  if feed_hash.empty?
    response = RestClient.get request_url
    redis.hmset(request_url, "feed", response, "count", 1)
    response
  else
    redis.hincrby(request_url, "count", 1)
    feed_hash["feed"]
  end
end